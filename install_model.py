"""Download and load the chosen local voice model. Does not start Voice Dictate."""
import argparse
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", choices=("base.en", "large-v3-turbo"), default="base.en")
    parser.add_argument("--device", choices=("cpu", "cuda"), default="cpu")
    args = parser.parse_args()
    dll_handles = []
    try:
        if args.device == "cuda" and os.name == "nt":
            for folder in (Path(sys.prefix) / "Lib/site-packages/nvidia").glob("*/bin"):
                dll_handles.append(os.add_dll_directory(str(folder)))
                os.environ["PATH"] = str(folder) + os.pathsep + os.environ.get("PATH", "")
        from faster_whisper import WhisperModel

        compute = "int8_float16" if args.device == "cuda" else "int8"
        print(f"Downloading/loading {args.model} on {args.device}. Cache: {ROOT / 'models'}")
        model = WhisperModel(args.model, device=args.device, compute_type=compute,
                             download_root=str(ROOT / "models"))
        del model
        print("Local voice model is ready.")
        return 0
    except Exception as error:
        print(f"Voice model setup failed: {error}", file=sys.stderr)
        print("Check internet access to Hugging Face, free disk space, and requirements.txt. "
              "For CUDA, check your NVIDIA driver and requirements-gpu.txt; "
              "rerun setup.cmd with the CPU option if needed.", file=sys.stderr)
        return 1
    finally:
        for handle in dll_handles:
            handle.close()


if __name__ == "__main__":
    sys.exit(main())
