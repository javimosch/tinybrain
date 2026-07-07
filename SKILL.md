---
name: tinybrain
description: Train tiny neural networks in pure machin (MFL) and ship them as JSON artifacts any MFL app embeds — MLP + SGD backprop for labeled data (classifiers/regressors, incl. bag-of-words intent routing), neuroevolution (GA + fitness closure) for control tasks (game AI), a deterministic PRNG for reproducible runs, and an agent-first CLI (train/predict/eval/guide). Use when an MFL program needs a learned controller, classifier, or scorer — NOT for generative text.
---

# tinybrain

Two trainers, one artifact, a dependency-free inference path. Everything is pure MFL — compose the modules with your program via `machin encode`.

## The 60-second version

```sh
# supervised, via the CLI (build once: machin encode src/tinybrain.src src/cli.src > tb.mfl && machin build tb.mfl -o tinybrain)
tinybrain guide                                            # JSON catalog
tinybrain train --data d.csv --topology 4,8,3 --out m.json # CSV rows: nin floats + nout floats (one-hot)
tinybrain predict --model m.json --input 1.5,2.0
tinybrain predict --model intents.json --text "how much is the pro tier"   # needs vocab in the artifact
tinybrain eval --model m.json --data d.csv
```

```go
// inference in your app (compose src/tinybrain.src):
n := net_load("model.json")
out := net_forward(n, []float{1.0, 0.0})
cls := net_predict_class(n, x)
label, conf := net_classify_text(n, "free text")   // if the artifact carries vocab+labels

// neuroevolution (compose src/evolve.src too) — fitness is code, so it's library-only:
fit := func(nn) { return my_sim_score(nn) }
cfg := evolve_cfg_default()
res, champ := evolve_run(net_new([]int{6, 8, 2}, []string{"tanh", "tanh"}, 42), fit, cfg)
net_save(champ, "champion.json")
```

## Artifact (tinybrain/v1)

`{"tinybrain":1, "topology":[...], "activations":[...], "weights":[[...]], "biases":[[...]], "vocab":[], "labels":[], "meta":{trained_by, seed, loss, epochs}}` — weights row-major `out×in` per layer; activations `tanh|sigmoid|relu|linear|softmax`, one per non-input layer; `vocab`/`labels` optional (text classifiers carry their own featurization). Full-precision floats (12 frac digits — `json()`'s %g would drift). Same seed → same artifact.

## What to know before touching it

- **Choose the trainer by the data.** Labeled rows → `net_train_sgd` (softmax output = cross-entropy; else MSE). A reward/simulation → `evolve_run` with a fitness closure. Don't backprop a control task; don't evolve a labeled dataset.
- **Tiny text datasets:** build the vocab with `tb_vocab_drop(tb_vocab(texts), tb_stopwords_en())` — leaving stopwords in makes function words carry class weight and routing goes to whack-a-mole. No hidden layer (`[V, nclasses]` + softmax) beats a hidden layer on <100 rows.
- **Fix misroutes with data, not knobs:** add the missing phrasing to the intent's training list and retrain (ms-fast, deterministic).
- **The racing-sim modules** (`src/racesim.src`, `game/race_game.src`) are the reference integration: headless training (`examples/race_train.src`) → `models/driver.json` → the raylib game loads it with zero training code.
- Tests: `machin test src/tinybrain.src src/tinybrain_test.src`, `machin test src/tinybrain.src src/evolve.src src/racesim.src src/m1_test.src`, `machin test src/tinybrain.src src/m3_test.src`.

## MFL gotchas this repo hit (v0.107)

- `[][]float{}` literals don't parse — reach nested slices through struct fields or an append-helper (`tb_mat_empty`).
- Appending to an outer slice inside `arena{}` is a **use-after-free** — compute inside, append outside.
- Structs are value types: callees mutate slice *contents* of a passed net, but meta field writes are lost — `evolve_run` returns the stamped champion as a second value.
- `json()` floats are 6-sig-digit %g — hence the custom `tb_fmt` serializer for weights.
- Named-return structs need explicit init (`ds = Dataset{}`) before field access.
- `args()[0]` is the program name.
- No `cos` builtin: `sin(x + pi()/2)`.
