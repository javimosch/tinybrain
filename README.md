# tinybrain

Train tiny neural networks in pure [machin](https://github.com/javimosch/machin) (MFL) and ship them as JSON artifacts any MFL app can embed — native games, backends, wasm.

Not a deep-learning framework. tinybrain is for **tiny goals**: game-AI controllers (cars that learn to drive a track), small classifiers (intent routing, data analysis), regressors/scorers. Generative text is out of scope, honestly and on purpose.

## M0 (this milestone)

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
| `tb_seed(s)` / `tb_randf()` | the deterministic PRNG (minstd LCG) |

## Roadmap

- **M1** — neuroevolution trainer (GA over fixed-topology nets, fitness closure) + headless oval-track racing sim: cars learn to lap without touching the borders.
- **M2** — the raylib top-down racing game that loads the trained artifact.
- **M3** — generalize + publish: CLI for the supervised path, intent-classifier demo, awesome-machin.
