# Word Search Puzzle Generator

A lightweight, browser-based app for generating printable word-search puzzles.

## Features

- Single-input word entry with tag-style chips
- Remove words with one click (`×`)
- Fixed grid options for predictable output: `12x12`, `16x16`, `20x20`, `24x24`
- Validation for words too long for selected grid size
- Suggested next allowed grid size when words do not fit
- Print-optimized layout for US Letter paper

## Tech Stack

- Vanilla HTML, CSS, and JavaScript
- No build step
- No dependencies

## Project Structure

- `index.html`: app markup
- `app.js`: interaction logic + puzzle generation
- `base.css`: shared styling
- `screen.css`: on-screen UI styling
- `print.css`: print-specific layout rules

## Run Locally

1. Open `index.html` in any modern browser.
2. Add words in the input and press `Enter` after each.
3. Choose a grid size.
4. Click **Generate Puzzle**.
5. Click **Print**.

## Behavior Notes

- Only letters `A-Z` are kept in words (input is normalized to uppercase).
- Duplicate words are ignored.
- Maximum supported grid is `24x24`.
- If a word exceeds `24` letters, you must shorten it.
