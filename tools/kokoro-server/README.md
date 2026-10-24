# Local voice for `smartward read`

A small server that gives SmartWard a natural reading voice using
[Kokoro](https://github.com/thewh1teagle/kokoro-onnx) (82M parameters,
Apache-2.0, runs on CPU). It listens on `127.0.0.1` only.

## Set up

Use Python 3.10–3.13 (`onnxruntime` may not have wheels for newer versions yet).

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
```

Download the model files from the
[kokoro-onnx releases](https://github.com/thewh1teagle/kokoro-onnx/releases)
into this folder: `kokoro-v1.0.onnx` (about 310 MB; an int8 build of about 90 MB
is also published) and `voices-v1.0.bin` (about 27 MB).

```bash
python server.py --model kokoro-v1.0.onnx --voices voices-v1.0.bin
```

The server uses your distribution's espeak-ng (`libespeak-ng1` and
`espeak-ng-data`, installed with most desktop Ubuntu setups). The copy bundled
with the Python packages aborted on the machine this was tried on.

## Use it

```bash
smartward read "speculative decoding"        # best match for these words
smartward read --summary                      # newest article, summary only
smartward read --voice bf_emma --speed 1.1
smartward read "vLLM" --out vllm.wav --no-play
```

Any server that speaks `POST /v1/audio/speech` (for example Kokoro-FastAPI)
works too; point `--tts-url` at it. SmartWard refuses addresses that aren't on
this machine.
