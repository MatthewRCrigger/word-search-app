const LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

const DIRECTIONS = [
  [1, 0],
  [0, 1],
  [1, 1],
  [-1, 0],
  [0, -1],
  [-1, -1],
  [1, -1],
  [-1, 1],
];
const ALLOWED_GRID_SIZES = [12, 16, 20, 24];

const wordEntry = document.getElementById("wordEntry");
const wordChips = document.getElementById("wordChips");
const gridSizeInputs = Array.from(document.querySelectorAll('input[name="gridSize"]'));
const validationMessage = document.getElementById("validationMessage");
const generateBtn = document.getElementById("generateBtn");
const printBtn = document.getElementById("printBtn");
const output = document.getElementById("output");
const emptyState = document.getElementById("emptyState");
const puzzleGrid = document.getElementById("puzzleGrid");
const wordList = document.getElementById("wordList");

/** @type {string[]} */
const wordsState = [];

/**
 * @typedef {string[][]} LetterGrid
 */

/**
 * @typedef {Object} PlacementResult
 * @property {LetterGrid} grid
 * @property {string[]} unplaced
 */

/**
 * Normalizes a raw word to uppercase A-Z only.
 *
 * @param {string} raw
 * @returns {string}
 */
function sanitizeWord(raw) {
  return raw.trim().toUpperCase().replace(/[^A-Z]/g, "");
}

/**
 * Splits a typed string into sanitized word candidates.
 *
 * @param {string} raw
 * @returns {string[]}
 */
function parseEnteredWords(raw) {
  return raw
    .split(/[\n,]/)
    .map(sanitizeWord)
    .filter(Boolean);
}

/**
 * Renders the current chip list in the UI.
 *
 * @returns {void}
 */
function renderWordChips() {
  wordChips.innerHTML = "";

  for (const word of wordsState) {
    const chip = document.createElement("span");
    chip.className = "word-chip";

    const text = document.createElement("span");
    text.textContent = word;

    const removeBtn = document.createElement("button");
    removeBtn.type = "button";
    removeBtn.className = "chip-remove";
    removeBtn.textContent = "×";
    removeBtn.setAttribute("aria-label", `Remove ${word}`);
    removeBtn.addEventListener("click", () => {
      removeWord(word);
      wordEntry.focus();
    });

    chip.append(text, removeBtn);
    wordChips.append(chip);
  }

  wordChips.classList.toggle("is-empty", wordsState.length === 0);
}

/**
 * Adds unique words from raw input into the chip list.
 *
 * @param {string} raw
 * @returns {number}
 */
function addWords(raw) {
  const candidates = parseEnteredWords(raw);
  let added = 0;

  for (const candidate of candidates) {
    if (wordsState.includes(candidate)) {
      continue;
    }
    wordsState.push(candidate);
    added += 1;
  }

  if (added > 0) {
    renderWordChips();
  }

  return added;
}

/**
 * Removes a word from the chip list.
 *
 * @param {string} word
 * @returns {void}
 */
function removeWord(word) {
  const index = wordsState.indexOf(word);
  if (index >= 0) {
    wordsState.splice(index, 1);
    renderWordChips();
  }
}

/**
 * Returns a snapshot of words currently in the chip list.
 *
 * @returns {string[]}
 */
function getWordsFromChips() {
  return [...wordsState];
}

/**
 * Suggests a practical minimum grid size based on word lengths and count.
 *
 * @param {string[]} words
 * @returns {number}
 */
function estimateSuggestedGridSize(words) {
  const longest = Math.max(0, ...words.map((w) => w.length));
  const totalLetters = words.reduce((sum, word) => sum + word.length, 0);
  const densityEstimate = Math.ceil(Math.sqrt(totalLetters * 1.7));
  return Math.max(8, longest, densityEstimate);
}

/**
 * Gets the currently selected allowed grid size.
 *
 * @returns {number}
 */
function getSelectedGridSize() {
  const selected = gridSizeInputs.find((input) => input.checked);
  const value = Number(selected?.value ?? ALLOWED_GRID_SIZES[0]);
  return ALLOWED_GRID_SIZES.includes(value) ? value : ALLOWED_GRID_SIZES[0];
}

/**
 * Finds the smallest allowed size that is >= desired size.
 *
 * @param {number} desired
 * @returns {number | null}
 */
function pickAllowedSizeAtOrAbove(desired) {
  const candidate = ALLOWED_GRID_SIZES.find((size) => size >= desired);
  return candidate ?? null;
}

/**
 * Builds an empty NxN letter grid.
 *
 * @param {number} size
 * @returns {LetterGrid}
 */
function createEmptyGrid(size) {
  return Array.from({ length: size }, () => Array.from({ length: size }, () => ""));
}

/**
 * Returns a random integer between 0 (inclusive) and max (exclusive).
 *
 * @param {number} max
 * @returns {number}
 */
function randomInt(max) {
  return Math.floor(Math.random() * max);
}

/**
 * Checks whether a word can be placed at the given origin and direction.
 *
 * @param {LetterGrid} grid
 * @param {string} word
 * @param {number} row
 * @param {number} col
 * @param {number} rowDelta
 * @param {number} colDelta
 * @returns {boolean}
 */
function fitsWord(grid, word, row, col, rowDelta, colDelta) {
  const size = grid.length;

  for (let i = 0; i < word.length; i += 1) {
    const r = row + rowDelta * i;
    const c = col + colDelta * i;

    if (r < 0 || c < 0 || r >= size || c >= size) {
      return false;
    }

    const current = grid[r][c];
    if (current && current !== word[i]) {
      return false;
    }
  }

  return true;
}

/**
 * Writes a word into the grid.
 *
 * @param {LetterGrid} grid
 * @param {string} word
 * @param {number} row
 * @param {number} col
 * @param {number} rowDelta
 * @param {number} colDelta
 * @returns {void}
 */
function writeWord(grid, word, row, col, rowDelta, colDelta) {
  for (let i = 0; i < word.length; i += 1) {
    const r = row + rowDelta * i;
    const c = col + colDelta * i;
    grid[r][c] = word[i];
  }
}

/**
 * Fills empty grid cells with random letters.
 *
 * @param {LetterGrid} grid
 * @returns {void}
 */
function fillRemainingCells(grid) {
  for (let r = 0; r < grid.length; r += 1) {
    for (let c = 0; c < grid.length; c += 1) {
      if (!grid[r][c]) {
        grid[r][c] = LETTERS[randomInt(LETTERS.length)];
      }
    }
  }
}

/**
 * Attempts to place each word once into a fresh grid.
 *
 * @param {string[]} words
 * @param {number} size
 * @returns {PlacementResult}
 */
function tryPlaceWords(words, size) {
  const grid = createEmptyGrid(size);
  const unplaced = [];

  for (const word of words) {
    let placed = false;

    for (let attempt = 0; attempt < 400; attempt += 1) {
      const [rowDelta, colDelta] = DIRECTIONS[randomInt(DIRECTIONS.length)];
      const row = randomInt(size);
      const col = randomInt(size);

      if (!fitsWord(grid, word, row, col, rowDelta, colDelta)) {
        continue;
      }

      writeWord(grid, word, row, col, rowDelta, colDelta);
      placed = true;
      break;
    }

    if (!placed) {
      unplaced.push(word);
    }
  }

  return { grid, unplaced };
}

/**
 * Generates the best puzzle by trying multiple randomized placements.
 *
 * @param {string[]} words
 * @param {number} size
 * @returns {PlacementResult | null}
 */
function generatePuzzle(words, size) {
  const sortedWords = [...words].sort((a, b) => b.length - a.length);
  let best = null;

  for (let attempt = 0; attempt < 120; attempt += 1) {
    const candidate = tryPlaceWords(sortedWords, size);

    if (!best || candidate.unplaced.length < best.unplaced.length) {
      best = candidate;
    }

    if (candidate.unplaced.length === 0) {
      fillRemainingCells(candidate.grid);
      return candidate;
    }
  }

  if (best) {
    fillRemainingCells(best.grid);
  }

  return best;
}

/**
 * Renders puzzle letters and printable word list.
 *
 * @param {LetterGrid} grid
 * @param {string[]} words
 * @returns {void}
 */
function renderPuzzle(grid, words) {
  document.documentElement.style.setProperty("--grid-size", String(grid.length));

  let printGridSize = "5.9in";
  let printCellFont = "11pt";
  if (grid.length >= 33) {
    printGridSize = "4.8in";
    printCellFont = "8pt";
  } else if (grid.length >= 29) {
    printGridSize = "5.1in";
    printCellFont = "9pt";
  } else if (grid.length >= 25) {
    printGridSize = "5.5in";
    printCellFont = "10pt";
  }
  document.documentElement.style.setProperty("--print-grid-size", printGridSize);
  document.documentElement.style.setProperty("--print-cell-font-size", printCellFont);

  puzzleGrid.innerHTML = "";
  for (let r = 0; r < grid.length; r += 1) {
    for (let c = 0; c < grid.length; c += 1) {
      const cell = document.createElement("div");
      cell.className = "cell";
      cell.textContent = grid[r][c];
      puzzleGrid.append(cell);
    }
  }

  wordList.innerHTML = "";
  for (const word of words) {
    const item = document.createElement("li");
    item.textContent = word;
    wordList.append(item);
  }
}

/**
 * Sets the output panel to an empty state with helper copy.
 *
 * @param {string} message
 * @returns {void}
 */
function setPreviewEmpty(message) {
  output.classList.add("is-empty");
  emptyState.textContent = message;
  printBtn.disabled = true;
}

/**
 * Marks preview as ready for print and hides the empty state.
 *
 * @returns {void}
 */
function setPreviewReady() {
  output.classList.remove("is-empty");
  printBtn.disabled = false;
}

/**
 * Updates status feedback under controls.
 *
 * @param {string} message
 * @param {"warn" | "ok"} [kind="warn"]
 * @returns {void}
 */
function setValidationMessage(message, kind = "warn") {
  validationMessage.textContent = message;
  validationMessage.className = `validation ${kind}`;
}

/**
 * Validates inputs and generates a new puzzle if valid.
 *
 * @returns {void}
 */
function generateFromInputs() {
  const size = getSelectedGridSize();
  const words = getWordsFromChips();

  if (words.length === 0) {
    setValidationMessage("Please add at least one word.");
    setPreviewEmpty("Add at least one word to preview your puzzle.");
    return;
  }

  const tooLongWords = words.filter((word) => word.length > size);
  if (tooLongWords.length > 0) {
    const longest = Math.max(...tooLongWords.map((w) => w.length));
    const desired = Math.max(longest, estimateSuggestedGridSize(words));
    const suggestion = pickAllowedSizeAtOrAbove(desired);
    if (longest > ALLOWED_GRID_SIZES[ALLOWED_GRID_SIZES.length - 1]) {
      setValidationMessage(
        `These words are too long for the max 24x24 grid: ${tooLongWords.join(", ")}. Shorten them to 24 letters or less.`
      );
    } else {
      setValidationMessage(
        `These words are longer than ${size}: ${tooLongWords.join(", ")}. Try ${suggestion} x ${suggestion}.`
      );
    }
    return;
  }

  const result = generatePuzzle(words, size);
  if (!result) {
    setValidationMessage("Could not generate puzzle. Try a larger grid.");
    return;
  }

  if (result.unplaced.length > 0) {
    const suggestion = pickAllowedSizeAtOrAbove(Math.max(size + 1, estimateSuggestedGridSize(words)));
    if (suggestion) {
      setValidationMessage(
        `Could not fit all words at ${size} x ${size}. Unplaced: ${result.unplaced.join(
          ", "
        )}. Try ${suggestion} x ${suggestion}.`
      );
    } else {
      setValidationMessage(
        `Could not fit all words at ${size} x ${size}. Unplaced: ${result.unplaced.join(
          ", "
        )}. Try fewer or shorter words.`
      );
    }
    return;
  }

  renderPuzzle(result.grid, words);
  setPreviewReady();
  setValidationMessage(`Puzzle generated with ${words.length} words.`, "ok");
}

wordEntry.addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    event.preventDefault();
    addWords(wordEntry.value);
    wordEntry.value = "";
    setValidationMessage("", "warn");
    return;
  }

  if (event.key === "Backspace" && !wordEntry.value && wordsState.length > 0) {
    removeWord(wordsState[wordsState.length - 1]);
  }
});

generateBtn.addEventListener("click", generateFromInputs);
printBtn.addEventListener("click", () => {
  window.print();
});

renderWordChips();
setPreviewEmpty("Add words and click Generate Puzzle to preview.");
