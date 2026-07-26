function splitLines(source) {
  if (source === "") return [];
  return source.match(/.*?(?:\r\n|\n|\r|$)/g).filter(Boolean);
}

function normalizeSource(source) {
  return String(source).replace(/\r\n?/g, "\n");
}

function countOccurrences(source, needle) {
  if (needle === "") return 0;
  let count = 0;
  let offset = 0;
  while ((offset = source.indexOf(needle, offset)) !== -1) {
    count += 1;
    offset += Math.max(needle.length, 1);
  }
  return count;
}

function findResync(oldLines, newLines, oldStart, newStart) {
  const newPositions = new Map();
  for (let index = newStart; index < newLines.length; index += 1) {
    const positions = newPositions.get(newLines[index]) || [];
    positions.push(index);
    newPositions.set(newLines[index], positions);
  }

  let best = null;
  for (let oldIndex = oldStart; oldIndex < oldLines.length; oldIndex += 1) {
    const positions = newPositions.get(oldLines[oldIndex]);
    if (!positions) continue;
    for (const newIndex of positions) {
      const distance = oldIndex - oldStart + newIndex - newStart;
      if (!best || distance < best.distance) {
        best = { oldIndex, newIndex, distance };
      }
      break;
    }
    if (best && oldIndex - oldStart > best.distance) break;
  }
  return best;
}

function findHunks(oldSource, newSource) {
  const oldLines = splitLines(oldSource);
  const newLines = splitLines(newSource);
  const hunks = [];
  let oldIndex = 0;
  let newIndex = 0;

  while (oldIndex < oldLines.length || newIndex < newLines.length) {
    if (oldLines[oldIndex] === newLines[newIndex]) {
      oldIndex += 1;
      newIndex += 1;
      continue;
    }

    const startOld = oldIndex;
    const startNew = newIndex;
    const resync = findResync(oldLines, newLines, oldIndex, newIndex);
    if (resync) {
      oldIndex = resync.oldIndex;
      newIndex = resync.newIndex;
    } else {
      oldIndex = oldLines.length;
      newIndex = newLines.length;
    }
    hunks.push({ startOld, endOld: oldIndex, startNew, endNew: newIndex });
  }

  return { oldLines, newLines, hunks };
}

function buildSourceEdits(oldSource, newSource) {
  oldSource = normalizeSource(oldSource);
  newSource = normalizeSource(newSource);

  if (oldSource === newSource) return [];
  if (oldSource === "") {
    throw new Error("Cannot safely multi-edit an existing empty script without replacing its whole source");
  }

  const { oldLines, newLines, hunks } = findHunks(oldSource, newSource);
  if (hunks.length === 1 && hunks[0].startOld === 0 && hunks[0].endOld === oldLines.length) {
    throw new Error("No shared source context exists for a safe granular multi_edit");
  }

  let simulated = oldSource;
  const edits = [];
  let hunkIndex = hunks.length - 1;
  while (hunkIndex >= 0) {
    const hunk = hunks[hunkIndex];
    let oldStart = hunk.startOld;
    let oldEnd = hunk.endOld;
    let newStart = hunk.startNew;
    let newEnd = hunk.endNew;
    let oldString = oldLines.slice(oldStart, oldEnd).join("");
    let newString = newLines.slice(newStart, newEnd).join("");

    while (oldString === "" || countOccurrences(simulated, oldString) !== 1) {
      if (oldStart > 0 && newStart > 0 && oldLines[oldStart - 1] === newLines[newStart - 1]) {
        oldStart -= 1;
        newStart -= 1;
      } else if (
        oldEnd < oldLines.length &&
        newEnd < newLines.length &&
        oldLines[oldEnd] === newLines[newEnd]
      ) {
        oldEnd += 1;
        newEnd += 1;
      } else if (hunkIndex > 0) {
        // A repeated changed block can exhaust the unchanged lines around it
        // before becoming unique. Coalesce it with the preceding change and
        // the shared lines between them instead of rejecting a safe push.
        hunkIndex -= 1;
        oldStart = hunks[hunkIndex].startOld;
        newStart = hunks[hunkIndex].startNew;
      } else {
        throw new Error("Could not find unique unchanged context for a safe granular multi_edit");
      }
      oldString = oldLines.slice(oldStart, oldEnd).join("");
      newString = newLines.slice(newStart, newEnd).join("");
    }

    simulated = simulated.replace(oldString, newString);
    edits.push({ old_string: oldString, new_string: newString });
    hunkIndex -= 1;
  }

  if (simulated !== newSource) {
    throw new Error("Generated multi_edit operations did not reproduce the requested source");
  }
  return edits;
}

module.exports = { buildSourceEdits, normalizeSource };
