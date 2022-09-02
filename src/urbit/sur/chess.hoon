|%
::
::  a chess player is one of two sides
+$  chess-side
  $~  %white
  $?  %white
      %black
  ==
::  a chess piece is one of six types
+$  chess-piece-type
  $~  %pawn
  $?  %pawn
      %knight
      %bishop
      %rook
      %queen
      %king
  ==
::
::  a pawn can be promoted to...
+$  chess-promotion
  $~  %queen
  $?  %knight
      %bishop
      %rook
      %queen
  ==
::
::  a chess piece is a cell of its side and type
+$  chess-piece
  $~  [%white %pawn]
  $:  chess-side
      chess-piece-type
  ==
::
::  a chess piece's rank is one of eight types
+$  chess-rank
  $~  %1
  ?(%1 %2 %3 %4 %5 %6 %7 %8)
::
::  a chess piece's file is one of eight types
+$  chess-file
  $~  %a
  ?(%a %b %c %d %e %f %g %h)
::
::  a chess square is a cell of file and rank
+$  chess-square
  $~  [%a %1]
  [chess-file chess-rank]
::
::  a chess piece on a square is a cell of
::  the square [file rank], and the %piece
+$  chess-piece-on-square
  [square=chess-square piece=chess-piece]
::
::  chess-traverser is either a chess-square, or
::  nothing; this prevents pieces moving off the board
+$  chess-traverser
  $-(chess-square (unit chess-square))
::
::  chess-transformer renders the other side's pieces
+$  chess-transformer
  $-(chess-piece-on-square *)
::
::  the chess board is a map of
::  chess squares and chess pieces...
::
+$  chess-board
::
::  ...its initial, default state is the
::  following map of `chess-piece-on-square`s...
  $~
    %-  my
    :~
      [[%a %1] [%white %rook]]
      [[%b %1] [%white %knight]]
      [[%c %1] [%white %bishop]]
      [[%d %1] [%white %queen]]
      [[%e %1] [%white %king]]
      [[%f %1] [%white %bishop]]
      [[%g %1] [%white %knight]]
      [[%h %1] [%white %rook]]
      [[%a %2] [%white %pawn]]
      [[%b %2] [%white %pawn]]
      [[%c %2] [%white %pawn]]
      [[%d %2] [%white %pawn]]
      [[%e %2] [%white %pawn]]
      [[%f %2] [%white %pawn]]
      [[%g %2] [%white %pawn]]
      [[%h %2] [%white %pawn]]
      [[%a %8] [%black %rook]]
      [[%b %8] [%black %knight]]
      [[%c %8] [%black %bishop]]
      [[%d %8] [%black %queen]]
      [[%e %8] [%black %king]]
      [[%f %8] [%black %bishop]]
      [[%g %8] [%black %knight]]
      [[%h %8] [%black %rook]]
      [[%a %7] [%black %pawn]]
      [[%b %7] [%black %pawn]]
      [[%c %7] [%black %pawn]]
      [[%d %7] [%black %pawn]]
      [[%e %7] [%black %pawn]]
      [[%f %7] [%black %pawn]]
      [[%g %7] [%black %pawn]]
      [[%h %7] [%black %pawn]]
    ==
  ::
  ::  ...but otherwise, has it no specific values
  (map chess-square chess-piece)
::
::  chess-castle asks if the player can castle
::  in the current position. kingside? queenside?
::  both? niether?
+$  chess-castle
  $~  %both
  $?  %both
      %queenside
      %kingside
      %none
  ==
::
::  the chess-position is a cell type, containing
::  the current state of the whole board
+$  chess-position
  $~  [*chess-board %white %both %both ~ 0 1]
  $:
    board=chess-board
  ::  whose turn is it?
    player-to-move=chess-side
  ::  can white castle?
    white-can-castle=chess-castle
  ::  can black castle?
    black-can-castle=chess-castle
  ::  where is the pawn en passant? if one exists
    en-passant=(unit chess-square)
  ::  how close are we to invoking the 50-move rule?
    ply-50-move-rule=@
  ::  how many moves have there been?
    move-number=@
  ==
::
::  chess-player is a name, a ship,
::  or an unknown signora
+$  chess-player
  $~  [%unknown ~]
  $%  [%name @t]
      [%ship @p]
      [%unknown ~]
  ==
::
::  the game's result is a win. loss, or draw
+$  chess-result
  $~  %'½–½'
  $?  %'1-0'
      %'0-1'
      %'½–½'
  ==
::
::  a chess-move is one of three types:
::  a regular move from one square to another,
::  potentially with a promotion,
::  a queen- or king-side castle,
::  or a finishing move with a result
+$  chess-move
  $~  [%end %'½–½']
  $%  [%move from=chess-square to=chess-square into=(unit chess-promotion)]
      [%castle ?(%queenside %kingside)]
      [%end chess-result]
  ==
::
::  chess-game records the finished game
+$  chess-game
  $~  :*  game-id=*@dau
          event='?'
          site='Urbit Chess'
          date=*@da
          round=~
          white=*chess-player
          black=*chess-player
          result=~
          moves=~
      ==
  $:
    game-id=@dau
    event=@t
    site=@t
    date=@da
    ::  the round's default value is 
    ::  ~ if unknown, `~ if inappropriate
    round=(unit (list @))
    white=chess-player
    black=chess-player
    result=(unit chess-result)
    moves=(list chess-move)
  ==
::
::  a chess challenge comes with your challenger's
::  side, the type of event, and a round number
+$  chess-challenge
  $~  :*  challenger-side=%random
          event='Casual Game'
          round=`~
      ==
  $:
    challenger-side=?(chess-side %random)
    event=@t
    round=(unit (list @))
  ==
::
::  you can take seven types of action in %chess...
+$  chess-action
  $%  [%challenge who=ship challenge=chess-challenge]
      [%accept-game who=ship]
      [%decline-game who=ship]
      [%offer-draw game-id=@dau]
      [%accept-draw game-id=@dau]
      [%decline-draw game-id=@dau]
      [%move game-id=@dau move=chess-move]
  ==
::
::  ...and %chess can recieve five types of update
::  (@dau is a @da)
+$  chess-update
  $%  [%challenge who=ship challenge=chess-challenge]
      [%position game-id=@dau position=@t]
      [%result game-id=@dau result=chess-result]
      [%draw-offer game-id=@dau]
      [%draw-declined game-id=@dau]
  ==
::
::
::  chess-rng is a 256-bit hash
::  TODO: better describe purpose of hash; this all has something to do with preventing cheating
::  (@uvH is an unsigned 256-bit integer)
+$  chess-rng
  $%  [%commit p=@uvH]
      [%reveal p=@uvH]
  ==
::
::  TODO: figure out from app/chess.hoon
+$  chess-commitment
  $:  our-num=@uvH
      our-hash=@uvH
      her-num=(unit @uvH)
      her-hash=(unit @uvH)
      revealed=_|
  ==
--
