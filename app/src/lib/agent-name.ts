/**
 * A display name typed by a human → the agent name Timon will actually use.
 *
 * The daemon is authoritative (`orchestrator/src/onboarding-main-agent.ts`
 * holds the same conversion, and it is the one that writes the directory).
 * This copy exists so the onboarding screen can SHOW the result while the
 * user types instead of surprising them after the fact — an agent name is a
 * filesystem identity, so "Nova, mon assistante" cannot be one verbatim.
 *
 * Letters from any script are kept: a Chinese display name is a valid folder
 * name on every platform Timon ships for.
 */
export const AGENT_NAME_RE = /^(?!\.\.?$)[\p{L}\p{M}\p{N}._-]+$/u;

export function toAgentName(raw: string): string {
  return raw
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[^\p{L}\p{M}\p{N}._-]+/gu, '-')
    .replace(/-{2,}/g, '-')
    .replace(/^[-.]+|[-.]+$/g, '')
    .slice(0, 48);
}
