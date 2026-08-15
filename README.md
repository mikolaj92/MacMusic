# MacMusic

macOS composer for [MiniMax-Music3](https://huggingface.co/MiniMaxAI/MiniMax-Music3). Lyrics + caption → local stereo WAV.

The engine is a separate SPM package: [minimax-music3-swift](https://github.com/mikolaj92/minimax-music3-swift).

## Run

```bash
swift build -c release --product MiniMaxMusic
open .build/release/MiniMaxMusic
```

On first launch, **Download 4-bit** pulls [mikoy92/MiniMax-Music3-MLX-4bit](https://huggingface.co/mikoy92/MiniMax-Music3-MLX-4bit) into Application Support (~7 GB). Or point the app at a local converted MLX folder.

## License

App code is Apache-2.0. MiniMax-Music3 **weights** stay under the [MiniMax-Music3 Community License](https://huggingface.co/MiniMaxAI/MiniMax-Music3). See `NOTICE`.
