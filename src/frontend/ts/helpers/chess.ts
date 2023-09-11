import { ChessInstance, Square, SQUARES, WHITE, PAWN } from 'chess.js'
import { Ship, Results } from '../types/urbitChess'
import useChessStore from '../state/chessStore'

/**
 * Determine if a chess move is a pawn promotion
 */
export function isChessPromotion (orig: Square, dest: Square, chess: ChessInstance): boolean {
  const destRank = dest.charAt(1)

  if ((chess.get(orig).type === PAWN) && ((destRank === '1') || (destRank === '8'))) {
    return true
  }

  return false
}

/**
 * Use chess.js to compute the complete list of valid moves for the current FEN
 */
export function getChessDests (chess: ChessInstance): Map<string, string[]> {
  const dests = new Map<string, string[]>()

  SQUARES.forEach(function (s: Square) {
    const ms = chess.moves({ square: s, verbose: true })
    if (ms.length) {
      dests.set(s, ms.map(m => m.to))
    }
  })

  return dests
}

export function getTally (ship: Ship): String {
  // const { urbit, tallies } = useChessStore()
  const { tallies } = useChessStore()

  let tally: string;

  // console.log(`~${urbit.ship}'s getTally tallies`, tallies)
  if (!tallies.has(ship)) {
    tally = '0 - 0';
  } else {
      const results = tallies.get(ship)
      // console.log(`~${urbit.ship}'s getTally results:`, results);
      const ourWins = results.losses
      const oppWins = results.wins
      const draws = (results.draws % 2) === 1 ? '½' : '';
      // console.log(`~${urbit.ship}'s getTally draws:`, draws);

      tally = `${ourWins}${draws} - ${oppWins}${draws}`
  }

  return tally
}
