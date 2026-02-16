# luketn-wellness

Menu bar macOS wellness app (SwiftUI) with:

- Gratitude journal entry UI (5 prompts)
- Daily savor reminder on first login of the day
- Sleep-triggered gratitude reminder
- Markdown journal persistence to `~/OneDrive/GratitudeJournal/journal-YYYY-MM-DD.md`

## Run

Open in Xcode and run the `luketn-wellness` executable target, or run:

```bash
swift run
```

The app runs as a menu bar accessory (`LSUIElement`-style behavior via activation policy).
