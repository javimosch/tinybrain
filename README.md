# tinybrain

Train tiny neural networks in pure [machin](https://github.com/javimosch/machin) (MFL) and ship them as JSON artifacts any MFL app can embed — native games, backends, wasm.

Not a deep-learning framework. tinybrain is for **tiny goals**: game-AI controllers (cars that learn to drive a track), small classifiers (intent routing, data analysis), regressors/scorers. Generative text is out of scope, honestly and on purpose.

## M3 — the CLI + text classifiers

```sh
machin encode src/tinybrain.src src/cli.src > tb.mfl && machin build tb.mfl -o tinybrain

tinybrain guide                                                  # JSON catalog (agent-first)
tinybrain train --data blobs.csv --topology 2,8,3 --out m.json   # {"loss":0.00029,"train_accuracy":1,"train_ms":13}
tinybrain predict --model m.json --input 3.1,2.9                 # {"output":[...],"class":1,...}
tinybrain eval --model m.json --data blobs.csv                   # {"accuracy":1,"rows":90}
tinybrain predict --model models/intents.json --text "how much is the pro tier"
#   {"output":[...],"class":1,"label":"pricing","confidence":0.9998}
```

The CLI covers the supervised path only — the evolve trainer's fitness function is *code* (a simulation), so it stays a library API by design.

**Text classification** (the honest version of "a simple chatbot"): the artifact optionally carries `vocab` + `labels`, so a bag-of-words intent classifier is fully self-contained — `net_load` + `net_classify_text(n, "free text")` and nothing else. `examples/intent.src` trains a 4-intent support router (greeting/pricing/cancel/human, 36 phrases, 38ms) that routes 4/4 unseen phrasings correctly. Two lessons baked into the library: filter stopwords out of the vocab (`tb_vocab_drop(tb_vocab(texts), tb_stopwords_en())` — otherwise function words carry class weight), and fix misroutes by adding a phrasing to the dataset, not by tuning knobs.

## M2 — the game

```sh
./build.sh      # vendors static raylib 5.0 if no system one
./race_game     # run from the repo root — loads models/driver.json
```

`game/race_game.src` is the payoff: a raylib top-down view of the same elliptical circuit, with the **evolved artifact at the wheel** — the champion (green, its 5 ray sensors drawn) plus 4 mutated variants of its genome. Crashed cars respawn and count their crashes, so the fitness differences are visible live: the champion laps cleanly at ~27 speed while a bad mutant piles up crashes. The game contains **zero training code** — it composes the unchanged `racesim.src` for physics and calls `net_load` + `net_forward`, which is the whole point of the artifact contract.

Note: the GUI binary links raylib/GL/X11, so it needs a display — machin's no-dependency-binary property holds for the headless trainer, not the game.

## M1 — neuroevolution + the racing sim

- **`src/evolve.src`** — a genetic-algorithm trainer over fixed-topology nets: no gradients, no labels, just a fitness closure `func(net) float`. Tournament selection, uniform crossover, per-gene mutation, elitism, early stop on a target fitness, live-tailable JSONL log (one line per generation: `{"gen":i,"best":f,"mean":f}`).
- **`src/racesim.src`** — a headless oval-circuit driving sim: an **elliptical** ring (curvature varies, so a constant-steering policy provably cannot lap it — tested), 5 analytic ray sensors + speed in, steering + throttle out, death on border contact. Fully analytic, thousands of episodes/second, zero graphics — the M2 game will reuse it unchanged and just draw.
- **The result**: `examples/race_train.src` evolves a `[6,8,2]` driver from random weights to **4.3 clean laps in 90 simulated seconds** (physical optimum ≈ 4.7) in 7 generations / ~650ms, and saves `models/driver.json` — the artifact the game loads.

```sh
# both suites: 24 + 21 assertions
machin test src/tinybrain.src src/tinybrain_test.src
machin test src/tinybrain.src src/evolve.src src/racesim.src src/m1_test.src

# evolve the driver -> models/driver.json + models/race_train.jsonl
machin encode src/tinybrain.src src/evolve.src src/racesim.src examples/race_train.src > /tmp/rt.mfl
machin run /tmp/rt.mfl
```

```go
// evolve anything: give it a net and a fitness closure
fit := func(nn) {
    ep := sim_episode(nn, track_default(), 2700)
    f := abs(ep.progress)
    if ep.crashed { f = f - 1.0 }
    return f
}
cfg := evolve_cfg_default()          // pop 60, elite 4, mut 0.15/0.4, seed 42
cfg.target_fitness = 4.3 * 2.0 * pi()
res, champ := evolve_run(net_new([]int{6, 8, 2}, []string{"tanh", "tanh"}, 42), fit, cfg)
net_save(champ, "models/driver.json")
```

Honesty notes: a lucky *random* net can already lap this track slowly (reactive wall-avoidance is easy — the sim would be dishonest if it pretended otherwise); what evolution demonstrably adds is **refinement toward the optimum** (3.3 → 4.3 laps). And `evolve_run` returns the stamped champion as a second value because MFL structs are value types — the caller's net gets the champion *weights* (shared slices) but not the meta.

## M0



- **MLP core** — arbitrary topology, `tanh` / `sigmoid` / `relu` / `linear` / `softmax` activations, pure-MFL forward pass (a few matmuls — runs per-frame at 60fps trivially).
- **SGD backprop trainer** — MSE loss, or cross-entropy when the output layer is `softmax`.
- **Deterministic PRNG** — same seed → same weights → same trained artifact. Reproducible runs, agent-first.
- **JSON artifact** (`tinybrain/v1`) — human/agent-readable, diffable, full-precision weights (custom serializer; `json()`'s 6-digit `%g` would drift). Save/load round-trip is behavior-identical (tested to 1e-9).
- **CSV loading** — rows of `nin` input floats + `nout` output floats (one-hot for classification), `#` comments skipped.

## Quickstart

```sh
# run the test suite (24 assertions: XOR, artifact round-trip, 3-class blobs >95% acc)
machin test src/tinybrain.src src/tinybrain_test.src

# train XOR, save models/xor.json, reload it, predict — ~6ms
machin encode src/tinybrain.src examples/xor.src > /tmp/xor.mfl
machin run /tmp/xor.mfl
```

## Using a trained artifact in your app

Compose `src/tinybrain.src` with your program (`machin encode src/tinybrain.src app.src > app.mfl`), then:

```go
n := net_load("models/xor.json")
out := net_forward(n, []float{1.0, 0.0})   // -> [0.986...]
cls := net_predict_class(n, inputs)         // argmax, for classifiers
```

## Artifact format (tinybrain/v1)

```json
{
  "tinybrain": 1,
  "topology": [2, 4, 1],
  "activations": ["tanh", "sigmoid"],
  "weights": [[...], [...]],
  "biases": [[...], [...]],
  "meta": {"trained_by": "sgd", "seed": 42, "loss": 0.000124, "epochs": 3000}
}
```

`weights[l]` is layer *l*'s matrix flattened row-major (`out × in`); `activations[l]` applies to layer *l+1*. `meta.seed` + the deterministic PRNG make training reproducible.

## API

| function | what |
|---|---|
| `net_new(topology, activations, seed)` | fresh net, weights uniform ±1/√fan_in |
| `net_forward(n, x)` | inference: `[]float` → `[]float` |
| `net_predict_class(n, x)` | argmax of the output layer |
| `net_train_sgd(n, ds, epochs, lr)` | online SGD backprop; returns final mean loss |
| `net_save(n, path)` / `net_load(path)` | artifact I/O |
| `csv_load(path, nin, nout)` | CSV → `Dataset{x, y}` |
| `net_accuracy(n, ds)` | classification accuracy vs one-hot labels |
|  `tb_seed(s)` / `tb_randf()` | the deterministic PRNG (minstd LCG) |

## Status


M0–M3 complete. Ideas beyond: more activations/optimizers if a dogfood app needs them, a wasm inference demo, more sims for the evolve trainer.
