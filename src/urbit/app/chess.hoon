::  chess: fully decentralized, peer-to-peer chess app for urbit
::
::  import libraries and expose namespace
/-  *historic
/+  *chess, dbug, default-agent, pals
::
::  define state structures
|%
+$  versioned-state
  $%  state-0
      state-1
  ==
+$  active-game-state
  $:  game=chess-game
      position=chess-position
      fen-repetition=(map @t @ud)
      special-draw-available=?
      ready=?
      sent-draw-offer=?
      got-draw-offer=?
      auto-claim-special-draws=?
  ==
+$  state-1
  $:  %1
      games=(map @dau active-game-state)
      archive=(map @dau chess-game)
      challenges-sent=(map ship chess-challenge)
      challenges-received=(map ship chess-challenge)
      rng-state=(map ship chess-commitment)
  ==
+$  card  card:agent:gall
--
%-  agent:dbug
=|  state-1
=*  state  -
^-  agent:gall
=<
|_  =bowl:gall
+*  this     .
    default  ~(. (default-agent this %|) bowl)
++  on-init
  ^-  (quip card _this)
  :_  this
  ::
  ::  XX: remove these cards
  ::
  ::  these are initialization steps from before
  ::  the software distribution update and should be removed
  :~  :*  %pass  /srv
          %agent  [our.bowl %file-server]
          %poke  %file-server-action
          !>([%serve-dir /'~chess' /app/chess | &])
      ==
      :*  %pass  /chess
          %agent  [our.bowl %launch]
          %poke  %launch-action
          !>  :*  %add  %chess
                  [[%basic 'chess' '' '/~chess'] &]
              ==
      ==
  ==
++  on-save
  !>(state)
++  on-load
  |=  old-state-vase=vase
  ^-  (quip card _this)
  =/  old-state  !<(versioned-state old-state-vase)
  ?-  -.old-state
    %1  [~ this(state old-state)]
    %0  [~ this(state *state-1)]
  ==
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+  mark  (on-poke:default mark vase)
    ::
    ::  pokes managing active game state and challenges
    %chess-action
      ::  only allow chess actions from our ship or our moons
      ?>  (team:title our.bowl src.bowl)
      =/  action  !<(chess-action vase)
      ?-  -.action
        ::  manage new outgoing challenges
        %challenge
          ::  only allow one active challenge per ship
          ::  XX: change or display to frontend
          ?:  (~(has by challenges-sent) who.action)
            :_  this
            =/  err
              "already challenged {<who.action>}"
            :~  [%give %poke-ack `~[leaf+err]]
            ==
          ::  send new challenge
          :-  :~  :*  %pass  /poke/challenge  %agent  [who.action %chess]
                      %poke  %chess-challenge  !>(challenge.action)
                  ==
              ==
          ::  add to list of outgoing challenges
          %=  this
            challenges-sent  (~(put by challenges-sent) +.action)
          ==
        %accept-game
          =/  challenge  (~(get by challenges-received) who.action)
          ?~  challenge
            :_  this
            =/  err
              "no challenge to accept from {<who.action>}"
            :~  [%give %poke-ack `~[leaf+err]]
            ==
          ::  XX: document chess-rng
          ?:  ?=(%random challenger-side.u.challenge)
            =/  our-num  (shaf now.bowl eny.bowl)
            =/  our-hash  (shaf %chess-rng our-num)
            :-  :~  :*  %pass  /poke/rng  %agent  [who.action %chess]
                        %poke  %chess-rng  !>([%commit our-hash])
                    ==
                ==
            %=  this
              rng-state  %+  ~(put by rng-state)  who.action
                         [our-num our-hash ~ ~ |]
            ==
          ::  assign ships to white and black
          =+  ^=  [white-player black-player]
            ?-  challenger-side.u.challenge
              %white
                [[%ship who.action] [%ship our.bowl]]
              %black
                [[%ship our.bowl] [%ship who.action]]
            ==
          ::  create a unique game id
          =/  game-id  (mix now.bowl (end [3 6] eny.bowl))
          ::  initialize new game
          =/  new-game  ^-  chess-game
            :*  game-id=game-id
                event=event.u.challenge
                site='Urbit Chess'
                date=(yule [d:(yell game-id) 0 0 0 ~])
                round=round.u.challenge
                white=white-player
                black=black-player
                result=~
                moves=~
            ==
          ::  subscribe to moves made on the
          ::  other player's instance of this game
          :-  :~  :*  %pass  /player/(scot %da game-id)
                      %agent  [who.action %chess]
                      %watch  /game/(scot %da game-id)/moves
                  ==
                  ::  add our new game to the list of active games
                  :*  %give  %fact  ~[/active-games]
                      %chess-game  !>(new-game)
                  ==
              ==
          %=  this
            ::  remove our challenger from challenges-received
            challenges-received  (~(del by challenges-received) who.action)
            ::  if the poke came from our ship, delete
            ::  the challenge from our `challenges-sent`
            challenges-sent  ?:  =(who.action our.bowl)
                               (~(del by challenges-sent) our.bowl)
                             challenges-sent
            ::  put our new game into the map of games
            games  (~(put by games) game-id [new-game *chess-position *(map @t @ud) | | | | |])
          ==
        %decline-game
          =/  challenge  (~(get by challenges-received) who.action)
          ?~  challenge
            :_  this
            =/  err
              "no challenge to decline from {<who.action>}"
            :~  [%give %poke-ack `~[leaf+err]]
            ==
          ::  tell our challenger we decline
          :-  :~  :*  %pass  /poke/challenge  %agent  [who.action %chess]
                      %poke  %chess-decline-challenge  !>(~)
                  ==
              ==
          %=  this
            ::  remove our challenger from challenges-received
            challenges-received  (~(del by challenges-received) who.action)
          ==
        %change-special-draw-preference
          =/  game  (~(get by games) game-id.action)
          ?~  game
            :_  this
            =/  err
              "no active game with id {<game-id.action>}"
            :~  [%give %poke-ack `~[leaf+err]]
            ==
          :-  :~  :*  %give
                      %fact
                      ~[/game/(scot %da game-id.action)/updates]
                      %chess-update
                      !>([%special-draw-preference game-id.action setting.action])
                  ==
              ==
          %=  this
            games  (~(put by games) game-id.action u.game(auto-claim-special-draws setting.action))
          ==
        %offer-draw
          =/  game  (~(get by games) game-id.action)
          ?~  game
            :_  this
            =/  err
              "no active game with id {<game-id.action>}"
            :~  [%give %poke-ack `~[leaf+err]]
            ==
          ::  send draw offer to opponent
          :-  :~  :*  %give  %fact  ~[/game/(scot %da game-id.action)/moves]
                      %chess-draw-offer  !>(~)
                  ==
              ==
          ::  record that draw has been offered
          %=  this
            games  (~(put by games) game-id.action u.game(sent-draw-offer &))
          ==
        %accept-draw
          =/  game-state  (~(get by games) game-id.action)
          ::  check for valid game
          ?~  game-state
            :_  this
            =/  err
              "no active game with id {<game-id.action>}"
            :~  [%give %poke-ack `~[leaf+err]]
            ==
          ::  check for open draw offer
          ?.  got-draw-offer.u.game-state
            :_  this
            =/  err
              "no draw offer to accept for game {<game-id.action>}"
              :~  [%give %poke-ack `~[leaf+err]]
              ==
          ::  tell opponent we accept the draw
          :-  :~  :*  %give  %fact  ~[/game/(scot %da game-id.action)/moves]
                      %chess-draw-accept  !>(~)
                  ==
                  ::  update observers that game ended in a draw
                  :*  %give  %fact  ~[/game/(scot %da game-id.action)/updates]
                      %chess-update
                      !>([%result game-id.action %'½–½'])
                  ==
                  ::  and kick subscribers who are listening to this agent
                  :*  %give  %kick  :~  /game/(scot %da game-id.action)/updates
                                        /game/(scot %da game-id.action)/moves
                                    ==
                      ~
                  ==
              ==
          =/  updated-game  game.u.game-state
          =.  result.updated-game  `(unit chess-result)``%'½–½'
          %=  this
            ::  remove this game from our map of active games
            games    (~(del by games) game-id.action)
            ::  add this game to our archive
            archive  (~(put by archive) game-id.action updated-game)
          ==
        %decline-draw
          =/  game  (~(get by games) game-id.action)
          ::  check for valid game
          ?~  game
            :_  this
            =/  err
              "no active game with id {<game-id.action>}"
            :~  [%give %poke-ack `~[leaf+err]]
            ==
          ::  check for open draw offer
          ?.  got-draw-offer.u.game
            :_  this
            =/  err
              "no draw offer to decline for game {<game-id.action>}"
              :~  [%give %poke-ack `~[leaf+err]]
              ==
          ::  decline draw offer
          :-  :~  :*  %give  %fact  ~[/game/(scot %da game-id.action)/moves]
                      %chess-draw-decline  !>(~)
                  ==
              ==
          %=  this
            ::  record that draw offer is gone
            games  (~(put by games) game-id.action u.game(got-draw-offer |))
          ==
        %claim-special-draw
          =/  game-state  (~(get by games) game-id.action)
          ?~  game-state
            :_  this
            =/  err
              "no active game with id {<game-id.action>}"
            :~  [%give %poke-ack `~[leaf+err]]
            ==
          =/  ship-to-move
            ?-  player-to-move.position.u.game-state
              %white
                white.game.u.game-state
              %black
                black.game.u.game-state
            ==
          ::  check whether it's our turn
          ?>  ?=([%ship @p] ship-to-move)
          ?.  (team:title +.ship-to-move src.bowl)
            :_  this
            =/  err
              "cannot claim special draw on opponent's turn"
            :~  [%give %poke-ack `~[leaf+err]]
            ==
          ::  check if a special draw claim is available
          ?.  special-draw-available.u.game-state
            :_  this
            =/  err
              "no special draw available for game {<game-id.action>}"
              :~  [%give %poke-ack `~[leaf+err]]
              ==
          :-  :~  :*  %give  %fact  ~[/game/(scot %da game-id.action)/moves]
                      %chess-game-result  !>([game-id.action %'½–½' ~])
                  ==
                  :*  %give  %fact  ~[/game/(scot %da game-id.action)/updates]
                      %chess-update
                      !>([%result game-id.action %'½–½'])
                  ==
                  :*  %give  %kick  :~  /game/(scot %da game-id.action)/updates
                                        /game/(scot %da game-id.action)/moves
                                    ==
                      ~
                  ==
              ==
          =/  updated-game  game.u.game-state
          =.  result.updated-game  `(unit chess-result)``%'½–½'
          %=  this
            games    (~(del by games) game-id.action)
            archive  (~(put by archive) game-id.action updated-game)
          ==
        %move
          =/  game-state  (~(get by games) game-id.action)
          ::  check for valid game
          ?~  game-state
            :_  this
            =/  err
              "no active game with id {<game-id.action>}"
            :~  [%give %poke-ack `~[leaf+err]]
            ==
          :: check opponent is subscribed to our updates
          ?.  ready.u.game-state
            :_  this
            =/  err
              "opponent not subscribed yet"
            :~  [%give %poke-ack `~[leaf+err]]
            ==
          ::  else, check whose move it should be right now
          =/  ship-to-move
            ?-  player-to-move.position.u.game-state
              %white
                white.game.u.game-state
              %black
                black.game.u.game-state
            ==
          ::  check whether it's our turn
          ?>  ?=([%ship @p] ship-to-move)
          ?.  (team:title +.ship-to-move src.bowl)
            :_  this
            =/  err
              "not our move"
            :~  [%give %poke-ack `~[leaf+err]]
            ==
          =/  move-result
            (try-move u.game-state move.action)
          ::  check the move is legal
          ?~  new.move-result
            :_  this
            =/  err
              "illegal move"
            %+  weld  cards.move-result
            ^-  (list card)
            :~  [%give %poke-ack `~[leaf+err]]
            ==
          =,  u.new.move-result
          :-  ?:  &(auto-claim-special-draws special-draw-available)
                ::  don't send extra move card if auto-claiming special draw
                cards.move-result
              ::  send move to opponent
              :_  cards.move-result
              :*  %give
                  %fact
                  ~[/game/(scot %da game-id.action)/moves]
                  %chess-move
                  !>(move.action)
              ==
          ::  check if game is over
          ?.  ?=(~ result.game)
            ::  if so, archive game
            %=  this
              games    (~(del by games) game-id.action)
              archive  (~(put by archive) game-id.action game)
            ==
          ::  otherwise, update position
          %=  this
            games  %+  ~(put by games)  game-id.action
                   u.new.move-result
          ==
      ==
    ::
    ::  handle incoming challenges
    %chess-challenge
      =/  challenge  !<(chess-challenge vase)
      :-  :~  :*  %give  %fact  ~[/challenges]
                  %chess-update  !>([%challenge src.bowl challenge])
              ==
          ==
      %=  this
        challenges-received
          (~(put by challenges-received) src.bowl challenge)
      ==
    ::
    ::  handle declined challenges
    %chess-decline-challenge
      :-  ~
      %=  this
        challenges-sent  (~(del by challenges-sent) src.bowl)
      ==
    ::
    ::  randomly assign sides for new games
    ::  XX further document rng logic
    %chess-rng
      =/  rng-data  !<(chess-rng vase)
      =/  commitment  (~(get by rng-state) src.bowl)
      ?-  -.rng-data
        %commit
          ?~  commitment
            ::  we're the challenger
            =/  our-num  (shaf now.bowl eny.bowl)
            =/  our-hash  (shaf %chess-rng our-num)
            :-  :~  :*  %pass  /poke/rng  %agent  [src.bowl %chess]
                        %poke  %chess-rng  !>([%commit our-hash])
                    ==
                ==
            %=  this
              rng-state  %+  ~(put by rng-state)  src.bowl
                         [our-num our-hash ~ `p.rng-data |]
            ==
          :: we're the accepter
          =/  updated-commitment
            [our-num.u.commitment our-hash.u.commitment ~ `p.rng-data &]
          :-  :~  :*  %pass  /poke/rng  %agent  [src.bowl %chess]
                      %poke  %chess-rng  !>([%reveal our-num.u.commitment])
                  ==
              ==
          %=  this
            rng-state  (~(put by rng-state) src.bowl updated-commitment)
          ==
        %reveal
          ?>  ?=(^ commitment)
          ?:  revealed.u.commitment
            ::  we're the accepter
            ?>  ?=(^ her-hash.u.commitment)
            ?.  =(u.her-hash.u.commitment (shaf %chess-rng p.rng-data))
              ~|  commitment  !!  ::  cheater
            =/  challenge  (~(get by challenges-received) src.bowl)
            ?~  challenge  !!
            =/  random-bit  %-  ?
              (end [0 1] (mix our-num.u.commitment p.rng-data))
            =/  white-player
              ?:  random-bit
                [%ship our.bowl]
              [%ship src.bowl]
            =/  black-player
              ?:  random-bit
                [%ship src.bowl]
              [%ship our.bowl]
            =/  game-id  (mix now.bowl (end [3 6] eny.bowl))
            =/  new-game  ^-  chess-game
              :*  game-id=game-id
                  event=event.u.challenge
                  site='Urbit Chess'
                  date=(yule [d:(yell game-id) 0 0 0 ~])
                  round=round.u.challenge
                  white=white-player
                  black=black-player
                  result=~
                  moves=~
              ==
            :-  :~  :*  %pass  /player/(scot %da game-id)
                        %agent  [src.bowl %chess]
                        %watch  /game/(scot %da game-id)/moves
                    ==
                    :*  %give  %fact  ~[/active-games]
                        %chess-game  !>(new-game)
                    ==
                ==
            %=  this
              challenges-received  (~(del by challenges-received) src.bowl)
              challenges-sent  ?:  =(src.bowl our.bowl)
                                 (~(del by challenges-sent) our.bowl)
                               challenges-sent
              rng-state  (~(del by rng-state) src.bowl)
              games  (~(put by games) game-id [new-game *chess-position *(map @t @ud) | | | | |])
            ==
          ::  we're the challenger
          ?>  ?=(^ her-hash.u.commitment)
          ?.  =(u.her-hash.u.commitment (shaf %chess-rng p.rng-data))
            ~|  commitment  !!::  cheater
          =/  final-commitment
            :*  our-num.u.commitment
                our-hash.u.commitment
                `p.rng-data
                her-hash.u.commitment
                &
            ==
          :-  :~  :*  %pass  /poke/rng  %agent  [src.bowl %chess]
                      %poke  %chess-rng  !>([%reveal our-num.u.commitment])
                  ==
              ==
          %=  this
            rng-state  (~(put by rng-state) src.bowl final-commitment)
          ==
      ==
    ::
    ::  directly inject FEN positions into games (for debugging)
    %chess-debug-inject
      ?>  =(src.bowl our.bowl)
      =/  action  !<([game-id=@dau game=chess-game] vase)
      =/  new-position  (play game.action)
      ?~  new-position
        :_  this
        =/  err
          "attempted to inject illegal game"
        :~  [%give %poke-ack `~[leaf+err]]
        ==
      =/  fen  (position-to-fen u.new-position)
      :-  :~  :*  %give  %fact  ~[/game/(scot %da game-id.action)/updates]
                  ::  XX: could replace ++rear of algebraicizing
                  ::      whole move list with arm algebraicizing
                  ::      just the one move
                  %chess-update  !>([%position game-id.action fen | (rear (algebraicize game.action))])
              ==
          ==
      %=  this
        games  (~(put by games) game-id.action [game.action u.new-position *(map @t @ud) | & | | |])
      ==
    ::
    ::  directly inject game subscriptions (for debugging)
    %chess-debug-subscribe
      ?>  =(src.bowl our.bowl)
      =/  action  !<([who=ship game-id=@dau] vase)
      :_  this
      :~  :*  %pass  /player/(scot %da game-id.action)
              %agent  [who.action %chess]
              %watch  /game/(scot %da game-id.action)/moves
          ==
      ==
    ::
    ::  delete game from state (for debugging)
    %chess-debug-zap
      ?>  =(src.bowl our.bowl)
      =/  action  !<(game-id=@dau vase)
      :-  ~
      %=  this
        games  (~(del by games) game-id.action)
      ==
  ==
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  (on-watch:default path)
    ::
    ::  convert incoming challenges to chess-update marks for subscribers
    [%challenges ~]
      ?>  (team:title our.bowl src.bowl)
      :_  this
      %+  turn  ~(tap by challenges-received)
      |=  [who=ship challenge=chess-challenge]
      ^-  card
      :*  %give  %fact  ~
          %chess-update  !>([%challenge who challenge])
      ==
    ::
    ::  convert active games to chess-game marks for subscribers
    [%active-games ~]
      ?>  (team:title our.bowl src.bowl)
      :_  this
      %+  turn  ~(tap by games)
      |=  [key=@dau game=chess-game * *]
      ^-  card
      :*  %give  %fact  ~
          %chess-game  !>(game)
      ==
    ::
    ::  starts a new game
    [%game @ta %moves ~]
      =/  game-id  `(unit @dau)`(slaw %da i.t.path)
      ?~  game-id
        :_  this
        =/  err
          "invalid game id {<i.t.path>}"
        :~  [%give %watch-ack `~[leaf+err]]
        ==
      ?:  (~(has by games) u.game-id)
        =/  game-state  (~(got by games) u.game-id)
        ?:  ready.game-state
          [~ this]
        =/  players  [white.game.game-state black.game.game-state]
        ::  ensure that the players in a game are our ship and the requesting ship
        ?:  ?|  =(players [[%ship our.bowl] [%ship src.bowl]])
                =(players [[%ship src.bowl] [%ship our.bowl]])
            ==
          :-  ~
          =/  new-game-state  game-state(ready &)
          %=  this
            games  (~(put by games) u.game-id new-game-state)
          ==
        [~ this]
      =/  challenge  (~(get by challenges-sent) src.bowl)
      ?~  challenge
        :_  this
        =/  err
          "no active game with id {<u.game-id>} or challenge from {<src.bowl>}"
        :~  [%give %watch-ack `~[leaf+err]]
        ==
      ::
      ::  assign white and black to players if random was chosen
      ?:  ?=(%random challenger-side.u.challenge)
        =/  commitment  (~(got by rng-state) src.bowl)
        =/  random-bit  %-  ?
          (end [0 1] (mix our-num.commitment (need her-num.commitment)))
        =/  white-player
          ?:  random-bit
            [%ship src.bowl]
          [%ship our.bowl]
        =/  black-player
          ?:  random-bit
            [%ship our.bowl]
          [%ship src.bowl]
        =/  new-game  ^-  chess-game
          :*  game-id=u.game-id
              event=event.u.challenge
              site='Urbit Chess'
              date=(yule [d:(yell u.game-id) 0 0 0 ~])
              round=round.u.challenge
              white=white-player
              black=black-player
              result=~
              moves=~
          ==
        ::  subscribe to updates from the other player's agent
        :-  :~  :*  %pass  /player/(scot %da u.game-id)
                    %agent  [src.bowl %chess]
                    %watch  /game/(scot %da u.game-id)/moves
                ==
                ::  send the new game as an update to the other player's agent
                :*  %give  %fact  ~[/active-games]
                    %chess-game  !>(new-game)
                ==
            ==
        %=  this
          challenges-sent  (~(del by challenges-sent) src.bowl)
          rng-state  (~(del by rng-state) src.bowl)
          games  (~(put by games) u.game-id [new-game *chess-position *(map @t @ud) | & | | |])
        ==
      ::  assign white and black to players if challenger chose
      =+  ^=  [white-player black-player]
        ?-  challenger-side.u.challenge
          %white
            [[%ship our.bowl] [%ship src.bowl]]
          %black
            [[%ship src.bowl] [%ship our.bowl]]
        ==
      =/  new-game  ^-  chess-game
            :*  game-id=u.game-id
                event=event.u.challenge
                site='Urbit Chess'
                date=(yule [d:(yell u.game-id) 0 0 0 ~])
                round=round.u.challenge
                white=white-player
                black=black-player
                result=~
                moves=~
            ==
      ::  subscribe to updates from the other player's agent
      :-  :~  :*  %pass  /player/(scot %da u.game-id)
                  %agent  [src.bowl %chess]
                  %watch  /game/(scot %da u.game-id)/moves
              ==
              ::  send the new game as an update to the other player's agent
              :*  %give  %fact  ~[/active-games]
                  %chess-game  !>(new-game)
              ==
          ==
      %=  this
        challenges-sent  (~(del by challenges-sent) src.bowl)
        games  (~(put by games) u.game-id [new-game *chess-position *(map @t @ud) | & | | |])
      ==
    ::
    ::  subscribe to updates on active games
    [%game @ta %updates ~]
      =/  game-id  `(unit @dau)`(slaw %da i.t.path)
      ?~  game-id
        :_  this
        =/  err
          "invalid game id {<i.t.path>}"
        :~  [%give %watch-ack `~[leaf+err]]
        ==
      ?.  (~(has by games) u.game-id)
        :_  this
        =/  err
          "no active game with id {<u.game-id>}"
        :~  [%give %watch-ack `~[leaf+err]]
        ==
      =/  game-state  (~(got by games) u.game-id)
      =/  fen  (position-to-fen position.game-state)
      =/  cards  ^-  (list card)
        :~  :*  %give  %fact  ~[/game/(scot %da u.game-id)/updates]
                %chess-update  !>([%position u.game-id fen special-draw-available.game-state ''])
            ==
        ==
      =?  cards  got-draw-offer.game-state
        :_  cards
        :*  %give  %fact  ~[/game/(scot %da u.game-id)/updates]
            %chess-update  !>([%draw-offer u.game-id])
        ==
      [cards this]
  ==
++  on-leave  on-leave:default
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  (on-peek:default path)
    ::
    ::  read game info
    ::  either active or archived
    [%x %game @ta ~]
      =/  game-id  `(unit @dau)`(slaw %da i.t.t.path)
      ?~  game-id  `~
      =/  active-game  (~(get by games) u.game-id)
      ?~  active-game
        =/  archived-game  (~(get by archive) u.game-id)
        ?~  archived-game  ~
        ``[%chess-game !>(u.archived-game)]
      ``[%chess-game !>(game.u.active-game)]
    ::
    ::  .^(noun %gx /=chess=/friends/noun)
    ::  .^(json %gx /=chess=/friends/json)
    ::  read mutual friends
    [%x %friends ~]
      ``[%chess-pals !>((~(mutuals pals bowl) ~.))]
    ::
    ::  .^(arch %gy /=chess=/game)
    ::  collect all the game-id keys
    [%y %game ~]
      :-  ~  :-  ~
      :-  %arch
      !>  ^-  arch
      :-  ~
      =/  ids  ~(tap in (~(uni in ~(key by archive)) ~(key by games)))
      %-  malt
      ^-  (list [@ta ~])
      %+  turn  ids
      |=  a=@dau
      [(scot %da a) ~]
  ==
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?+  wire  (on-agent:default wire sign)
    ::
    ::  remove a sent challenge on nack
    [%poke %challenge ~]
      ?+  -.sign  (on-agent:default wire sign)
        %poke-ack
          ?~  p.sign
            [~ this]
          %-  (slog u.p.sign)
          :-  ~
          %=  this
            challenges-sent  (~(del by challenges-sent) src.bowl)
          ==
      ==
    ::
    ::  handle actions from opponent player
    [%player @ta ~]
      =/  game-id  `(unit @dau)`(slaw %da i.t.wire)
      ?~  game-id
        [~ this]  ::  should leave the weird subscription here
      =/  game-state  (~(get by games) u.game-id)
      ?~  game-state
        [~ this]  ::  should leave the weird subscription here
      =/  ship-to-move
        ?-  player-to-move.position.u.game-state
          %white
            white.game.u.game-state
          %black
            black.game.u.game-state
        ==
      ?+  -.sign  (on-agent:default wire sign)
        %fact
          ?+  p.cage.sign  (on-agent:default wire sign)
            %chess-draw-offer
              :-  :~  :*  %give  %fact  ~[/game/(scot %da u.game-id)/updates]
                          %chess-update  !>([%draw-offer u.game-id])
                      ==
                  ==
              %=  this
                games  (~(put by games) u.game-id u.game-state(got-draw-offer &))
              ==
            %chess-draw-accept
              ::  first check whether we offered draw
              ?.  sent-draw-offer.u.game-state
                [~ this]  ::  nice try, cheater
              ::  log game as a draw, kick subscriber, and archive
              :-  :~  :*  %give  %fact  ~[/game/(scot %da u.game-id)/updates]
                          %chess-update
                          !>([%result u.game-id %'½–½'])
                      ==
                      :*  %give  %kick  :~  /game/(scot %da u.game-id)/updates
                                            /game/(scot %da u.game-id)/moves
                                        ==
                          ~
                      ==
                  ==
              =/  updated-game  game.u.game-state
              =.  result.updated-game  `%'½–½'
              %=  this
                games    (~(del by games) u.game-id)
                archive  (~(put by archive) u.game-id updated-game)
              ==
            %chess-draw-decline
              :-  :~  :*  %give  %fact  ~[/game/(scot %da u.game-id)/updates]
                          %chess-update  !>([%draw-declined u.game-id])
                      ==
                  ==
              %=  this
                games    (~(put by games) u.game-id u.game-state(sent-draw-offer |))
              ==
            ::
            ::  handle move legality, new games, and finished games
            %chess-move
              ::  ensure it’s the opponent ship’s turn
              ?.  =([%ship src.bowl] ship-to-move)
                [~ this]  :: nice try, cheater
              =/  move  !<(chess-move q.cage.sign)
              =/  move-result
                (try-move u.game-state move)
              ::  illegal move
              ?~  new.move-result
                [cards.move-result this]  ::  nice try, cheater
              =,  u.new.move-result
              :-  cards.move-result
              ?.  ?=(~ result.game)
              ::  archive games with results
                %=  this
                  games    (~(del by games) u.game-id)
                  archive  (~(put by archive) u.game-id game)
                ==
              ::  add new games to our list
              ::  XX: could this be where position update
              ::      isn't getting move data?
              %=  this
                games  %+  ~(put by games)  u.game-id
                       u.new.move-result
              ==
            %chess-game-result
              =/  result  !<(chess-game-result q.cage.sign)
              =/  result-game-state
                ?~  move.result
                  u.game-state
                =/  move-result  (try-move u.game-state (need move.result))
                ::  technically allows opponent to claim special draw with invalid move,
                ::  but only when a special draw is already available
                ::  so it doesn't break the game's correctness
                ?~  new.move-result
                  u.game-state
                u.new.move-result
              =,  result-game-state
              ?.  special-draw-available
                [~ this]  ::  nice try, cheater
              :_  %=  this
                    games    (~(del by games) u.game-id)
                    archive  (~(put by archive) u.game-id game.result-game-state(result `result.result))
                  ==
              :~  :*  %give
                      %fact
                      ~[/game/(scot %da u.game-id)/updates]
                      %chess-update
                      !>([%result u.game-id result.result])
                  ==
                  :*  %give  %kick  :~  /game/(scot %da u.game-id)/updates
                                        /game/(scot %da u.game-id)/moves
                                    ==
                      ~
                  ==
              ==
          ==
      ==
  ==
++  on-arvo   on-arvo:default
++  on-fail   on-fail:default
--
|%
::
::  helper core for moves
::  test if a given move is legal
++  try-move
  |=  [game-state=active-game-state move=chess-move]
  ^-  [new=(unit active-game-state) cards=(list card)]
  ?.  ?=(~ result.game.game-state)
    [~ ~]
  =/  new-position
    (~(apply-move with-position position.game-state) move)
  ?~  new-position
    [~ ~]
  =/  updated-game  `chess-game`game.game-state
  =.  moves.updated-game  (snoc moves.updated-game move)
  =/  new-fen-repetition  (increment-repetition fen-repetition.game-state u.new-position)
  =/  in-checkmate  ~(in-checkmate with-position u.new-position)
  =/  in-stalemate  ?:  in-checkmate
                      |
                    ~(in-stalemate with-position u.new-position)
  =/  special-draw-available  (check-threefold new-fen-repetition u.new-position)
  =/  special-draw-claim  &(special-draw-available auto-claim-special-draws.game-state)
  =/  position-update-card
  :*  %give  %fact  ~[/game/(scot %da game-id.game.game-state)/updates]
      %chess-update  !>([%position game-id.game.game-state (position-to-fen u.new-position) special-draw-available (rear (algebraicize updated-game))])
  ==
  ::  check if game ends by checkmate, stalemate, or special draw
  ?:  ?|  in-checkmate
          in-stalemate
          special-draw-claim
      ==
      ::  update result with score
      =.  result.updated-game
        ?:  in-stalemate  `%'½–½'
        ?:  special-draw-claim  `%'½–½'
        ?:  in-checkmate
          ?-  player-to-move.u.new-position
            %white  `%'0-1'
            %black  `%'1-0'
          ==
        !!
      ::  give a card of the game result to opponent ship
      :-  `[updated-game u.new-position new-fen-repetition special-draw-available |4.game-state]
      ?.  special-draw-claim
        :~  position-update-card
            :*  %give  %fact  ~[/game/(scot %da game-id.game.game-state)/updates]
                %chess-update
                !>([%result game-id.game.game-state (need result.updated-game)])
            ==
            ::  kick subscriber from game
            :*  %give  %kick  :~  /game/(scot %da game-id.game.game-state)/updates
                                  /game/(scot %da game-id.game.game-state)/moves
                              ==
                ~
            ==
        ==
      ::  if we're auto-claiming a special draw, send opponent our move with the result
      :~  position-update-card
          :*  %give  %fact  ~[/game/(scot %da game-id.game.game-state)/moves]
              %chess-game-result
              !>([game-id.game.game-state (need result.updated-game) `move])
          ==
          :*  %give  %fact  ~[/game/(scot %da game-id.game.game-state)/updates]
              %chess-update
              !>([%result game-id.game.game-state (need result.updated-game)])
          ==
          :*  %give  %kick  :~  /game/(scot %da game-id.game.game-state)/updates
                                /game/(scot %da game-id.game.game-state)/moves
                            ==
              ~
          ==
      ==
  :-  `[updated-game u.new-position new-fen-repetition special-draw-available |4.game-state]
  :~  position-update-card
  ==
++  increment-repetition
  |=  [fen-repetition=(map @t @ud) position=chess-position]
  ^-  (map @t @ud)
  =/  fen  ~(simplified position-to-fen position)
  =*  count  (~(get by fen-repetition) fen)
  ?~  count
    (~(put by fen-repetition) fen 1)
  (~(put by fen-repetition) fen +((need count)))
++  check-threefold
  |=  [fen-repetition=(map @t @ud) position=chess-position]
  ^-  ?
  =/  fen  ~(simplified position-to-fen position)
  =*  count  (~(get by fen-repetition) fen)
  ?~  count
    |
  (gth (need count) 2)
--
