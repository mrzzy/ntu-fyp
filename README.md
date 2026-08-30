# Broche

Broche is an AI-Assisted Drawing app for iPad that augments - rather than replaces - artists with generative AI. It pairs a familiar PencilKit sketching workflow with a **Sketch Agent**: an AI assistant that understands your drawings, iterates on them conversationally, and renders polished artwork on demand.

Developed as an NTU Final Year Project.

## Why Broche?

Existing AI image generation tools are largely single-shot: the user types a prompt, the model returns a finished image. This runs contrary to how artists actually work - gathering inspiration, sketching compositions, and refining iteratively. Broche bridges that gap by integrating state-of-the-art AI models into a drawing workflow inspired by apps like Procreate.

## Key Features

- **Sketch Assistant** - An agentic AI assistant, accessible via a familiar chat interface, that sees your sketch and takes actions (caption, explain edits, edit, render) through tool calls.
- **Iterative AI Editing** - Draw over an AI-generated image to indicate changes, then let the agent apply them. No inpainting masks required.
- **Mood Board** - Collect reference images and moods to guide the style of AI generations, similar to a Pinterest pin board.
- **Layered Sketch Architecture** - Drawings are a non-destructive stack of drawing and AI image layers; AI changes can be undone like any other edit.
- **Familiar Drawing UX** - PencilKit drawing with free zoom/rotation, undo/redo gestures (two-finger tap to undo), and PNG export.

## How It Works

The Sketch Agent is powered by three AI models behind a common interface: a **text LLM** (reasoning & tool calling), a **VLM** (understanding sketches), and a **diffusion model** (image generation & editing). Models are served online via OpenRouter and Replicate, while API keys are kept out of the app entirely - fetched from Firestore by authenticated users and rotated daily by a scheduled Firebase Cloud Function.

## Tech Stack

- **App**: Swift / SwiftUI, PencilKit, SwiftData, Firebase (Auth & Firestore)
- **AI**: OpenRouter (Qwen3 LLM, GPT-5 Nano VLM), Replicate (FLUX.2 Klein diffusion model)
- **Backend**: Firebase Cloud Functions (Node.js/TypeScript) for API key rotation
- **Testing**: Swift Testing (unit, mocked), integration & UI tests, Vitest (backend)

## Getting Started

### App

1. Open `broche.xcodeproj` in Xcode (requires iOS 26 SDK-era toolchain and an Apple Developer team for signing).
2. Let Swift Package Manager resolve dependencies.
3. Build and run on an iPad simulator or device.

### Backend

A scheduled Firebase Cloud Functions backend rotates the OpenRouter API key daily:

```bash
cd backend/functions
npm install
npm run serve   # run locally with emulators
npm run deploy  # deploy to Firebase
```

## Project Structure

```
├── broche/            # iOS app source (views, models, AI services)
├── brocheTests/       # iOS Unit tests (fully mocked, no network)
├── brocheIntegrationTests/  # iOS Live-API integration tests
└── backend/           # Firebase Cloud Functions (API key rotation)
```
