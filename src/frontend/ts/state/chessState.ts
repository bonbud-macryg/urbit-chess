import Urbit from '@urbit/http-api'
import { Ship, GameID, SAN, GameInfo, ActiveGameInfo, Challenge, ChessUpdate, ChallengeUpdate } from '../types/urbitChess'

interface ChessState {
  urbit: Urbit | null;
  displayGame: ActiveGameInfo | null;
  displayMoves: Array<SAN> | null;
  practiceBoard: String | null;
  activeGames: Map<GameID, ActiveGameInfo>;
  incomingChallenges: Map<Ship, Challenge>;
  setUrbit: (urbit: Urbit) => void;
  setDisplayGame: (displayGame: ActiveGameInfo | null) => void;
  setDisplayMoves: (displayMoves: Array<SAN> | null) => void;
  setPracticeBoard: (practiceBoard: String | null) => void;
  receiveChallenge: (data: ChallengeUpdate) => void;
  receiveGame: (data: GameInfo) => void;
  receiveUpdate: (data: ChessUpdate) => void;
  removeChallenge: (who: Ship) => void;
  declinedDraw: (gameID: GameID) => void;
  offeredDraw: (gameID: GameID) => void;
}

export default ChessState
