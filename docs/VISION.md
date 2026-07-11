# tinybrain — vision & north star

## North star

**Every machin program can afford a learned brain.** A tiny neural network —
trained in seconds on one machine, shipped as one diffable JSON file, loaded by
three lines of MFL — running anywhere machin runs: a native game at 60fps, a
92 kB backend binary, a wasm module in the browser. No Python, no GPU, no
dependency. When an MFL app needs a controller, a classifier, or a scorer, the
answer should be *"tinybrain, ten minutes"* — not *"bolt on an ML stack"*.

The measure of success: **consumers**. Every app that embeds an artifact —
and every framework feature that a real consumer forced into existence — is
the roadmap working as intended.

## What tinybrain is

- **A training framework for tiny goals.** Controllers (a car that laps a
  track, an arm that reaches a target), classifiers (intents, small tabular
  data), regressors/scorers. Nets with tens of neurons, artifacts of a few KB.
- **Two trainers, one artifact.** SGD backprop when you have labels;
  neuroevolution (GA + fitness closure) when you have a simulation. One
  `tinybrain/v1` JSON artifact either way, consumed by a dependency-free
  inference path.
- **Agent-first.** Deterministic PRNG — same seed, same artifact, reproducible
  runs. JSONL training logs an agent can tail. A CLI that speaks JSON both
  ways. Artifacts a human or agent can read, diff, and version-control.
- **Pure MFL, dogfood-driven.** The whole framework is composable `.src`
  modules; apps vendor it like they vendor machweb. When a consumer hits a
  wall, the fix lands in the framework (the robotic arm drove `warm_start`).

## What tinybrain is not (set in stone)

- **Not a deep-learning framework.** No GPU, no autodiff graph, no tensors, no
  layers zoo. If the problem needs more than a small MLP, it needs a different
  tool — say so honestly.
- **Not generative.** A tiny MLP will never be a chatbot. "Simple chatbot"
  means an intent classifier routing to templated responses — that's the
  honest version, and it's genuinely useful.
- **No Python interop, no ONNX, no ecosystem bridges.** The value is the
  closed loop inside machin.

## Doctrine: choose the trainer by the data

| you have | use | example |
|---|---|---|
| labeled rows | `net_train_sgd` | CSV classifier, intent router |
| a simulation + a score | `evolve_run` | racing driver |
| an expert to imitate + a sim | clone (SGD) → fine-tune (`evolve_run` + `warm_start`) | arm reacher vs analytic IK |

The third row is the flagship pattern: supervised cloning gets you into the
right basin, evolution optimizes what you actually care about (the closed-loop
score) — and with elitism the fine-tune can never regress below the clone.

Hard-won reacher lessons that generalize (encode them in any new control task):
feed **error vectors, not absolute goals** (don't make the net learn FK); feed
**velocities** (the damping channel — without it policies limit-cycle); weight
imitation data toward the **endgame regime**; put a **step bonus at the exact
success tolerance** so fitness measures what the benchmark measures; and always
report the **honest baseline** (pure evolution from scratch, the analytic
controller, the lucky random net).

## The artifact contract (tinybrain/v1)

The artifact is the product. Everything else exists to produce or consume it.

- JSON, human/agent-readable, full-precision weights (a save/load round-trip is
  behavior-identical).
- Self-contained: topology + activations + weights + biases + (for text
  classifiers) vocab + labels + provenance meta (trainer, seed, loss, epochs).
- Consumers never import a trainer: `net_load` + `net_forward` /
  `net_classify_text` is the whole surface.
- Backward compatibility matters from here on: v1 artifacts keep loading; new
  optional fields must default sanely (as `vocab`/`labels` did).

## Consumers (the scoreboard)

1. **Racing** (flagship, in-repo): evolve a driver headless → the raylib game
   and the [browser wasm demo](https://javimosch.github.io/tinybrain/) load the
   same `driver.json`. Zero training code in the consumers.
2. **Robotic arm** ([machin-demo-game-robotic-arm](https://github.com/javimosch/machin-demo-game-robotic-arm)):
   clone + fine-tune vs an analytic-IK ground truth; drove `warm_start`.
3. **Intent router** (in-repo example + CLI `--text`): the honest chatbot.

Wanted next: a scorer inside a machin backend (e.g. lead scoring in an
agent-first CLI), more sims pointed at `evolve_run`, a wasm-embedded classifier
in a real page.

## Delivered by consumer pull

- **Parallel fitness evaluation** (`cfg.workers`) — `go`/`chan` over the
  population, bit-identical to sequential, race-inference-verified. Pulled by
  the [machin-walker](https://github.com/javimosch/machin-walker) locomotion
  runs, where episodes are expensive.
- **Evolution Strategy trainer** (`es_run`) — antithetic Gaussian sampling +
  centered-rank-weighted gradient step on a mean genome; reuses the parallel
  worker pool, same `(res, champ)` contract as `evolve_run`. Pulled by the
  walker when tournament-GA proved sample-inefficient for continuous control.
- **Hall-of-Fame self-play co-evolution** (`coevolve_run`) — for COMPETITIVE
  tasks where fitness is relative (a policy vs an opponent), not absolute. Two
  domain closures (`matchfn`, `anchorfn`); the framework runs population + a
  sampled league of past champions + an anchor (the red-queen-trap fix), and
  returns the best-absolute champion plus the HoF timeline (a ready-made Elo
  ladder). Pulled by [machin-pong](https://github.com/javimosch/machin-pong) —
  two nets that learn Pong by playing each other, no data, no scripted expert.

## Roadmap candidates (pull, don't push)

Features enter when a consumer needs them, roughly in this order of likelihood:

- **Adaptive sigma / LR** for `es_run` (decay schedule or 1/5-rule) — the fixed
  `es_sigma`/`es_lr` are a starting point; add scheduling when a consumer
  measurably stalls without it.
- **A DAgger helper** — the clone→rollout→relabel→retrain loop as a framework
  function instead of app code (the arm wrote it by hand).
- **Momentum / minibatch SGD** — when a supervised consumer outgrows online SGD.
- **Compact artifact variant** — only if an artifact ever gets big enough to
  matter; JSON stays the canonical form.

Non-candidates until a real consumer proves the need: conv/recurrent layers,
autodiff beyond the fixed MLP, model zoos, Python anything.
