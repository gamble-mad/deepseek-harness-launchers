# desk-loop lanes — owner ruling 2026-09-17

| lane | model id (harness) | version expected | effort | role | permissions |
|---|---|---|---|---|---|
| PRO HIGH | `deepseek-v4-pro` | DeepSeek-V4-Pro-0813 | high | plan · review · escalate · implement only when decomposition is impractical | reads anywhere the packet names; writes only when the packet authorizes; its material work needs a separate review session + owner approval |
| FLASH MAX | `deepseek-v4-flash` (alias of `deepseek-flash`) | DeepSeek-V4.1-Flash | max | default builder: bounded implementation, tests, fixes, mechanical refactors, recon, test/fix loops | writes only the packet's allowed-writes list; two bounded repair attempts, then stop for Pro High |

Packet minimum (both lanes): one objective · exact scope · repo map and files · contracts/invariants ·
exclusions · allowed writes · validation commands · output requirements · stop condition. A packet missing
one of these is answered `BLOCKED | packet incomplete | <missing item> | Opus`.

Identity gate, first action of every session: read the model id the harness declares, print it as the first
line of the report, compare with the packet's `model:` line. Different → stop. Effort is not readable in this
harness; quote the packet's value as declared, not verified.

Pro High review of Flash work (Build gate step 6): a new session, given the original packet and `git diff
<base>..HEAD`; judges requirements, contracts, invariants, failure behaviour, tests, unauthorized drift —
not cosmetics. Returns `{drift, findings[], verdict}` like a guardian.

Green tests are evidence, never merge authority. No lane approves or merges its own consequential work.
