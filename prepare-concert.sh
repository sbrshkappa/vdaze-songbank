#!/bin/bash

# Concert Preparation Script
# Usage: ./prepare-concert.sh <concert-name>
# Example: ./prepare-concert.sh 2024-01-15-venue-name

if [ $# -eq 0 ]; then
    echo "Usage: $0 <concert-name>"
    echo "Example: $0 2024-01-15-venue-name"
    exit 1
fi

CONCERT_NAME="$1"
CONCERT_FILE="concerts/${CONCERT_NAME}.txt"
TEMP_DIR="temp-concerts/${CONCERT_NAME}"

# Check if concert file exists
if [ ! -f "$CONCERT_FILE" ]; then
    echo "Error: Concert file '$CONCERT_FILE' not found!"
    echo "Available concerts:"
    ls concerts/*.txt 2>/dev/null | sed 's/concerts\///g' | sed 's/\.txt$//g' | sed 's/^/  /'
    exit 1
fi

# Create temp directory
mkdir -p "$TEMP_DIR"

echo "Preparing concert: $CONCERT_NAME"
echo "Reading from: $CONCERT_FILE"
echo "Creating temp directory: $TEMP_DIR"
echo ""

# Process each song in the concert file
while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines and comments
    # Strip any trailing carriage return (in case of CRLF)
    line=${line%$'\r'}
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    
    # Parse song file and transposition
    read -r song_file transpose <<< "$line"
    
    if [ -z "$song_file" ]; then
        continue
    fi
    
    # Default transpose to 0 if not specified
    transpose=${transpose:-0}
    
    echo "Processing: $song_file (transpose: $transpose)"
    
    # Check if source file exists
    if [ ! -f "$song_file" ]; then
        echo "  Warning: Source file '$song_file' not found, skipping..."
        continue
    fi
    
    # Create transposed version
    python3 -c "
import sys
import re

def transpose_chord(chord, semitones):
    # Skip special characters that shouldn't be transposed
    special_chars = ['\\\\', '%', 'x2', 'x3', 'x4', 'x5', 'x6']
    if not chord or chord.strip() in special_chars:
        return chord
    
    # Preserve leading offbeat marker '&' by transposing the following chord only
    if chord.startswith('&'):
        return '&' + transpose_chord(chord[1:], semitones)

    # Chord mapping for transposition
    chord_map = {
        'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5,
        'F#': 6, 'Gb': 6, 'G': 7, 'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11
    }
    
    # Find the root note
    root_match = re.match(r'^([A-G][#b]?)', chord)
    if not root_match:
        return chord
    
    root = root_match.group(1)
    if root not in chord_map:
        return chord
    
    # Calculate new root
    new_root_semitones = (chord_map[root] + semitones) % 12
    if new_root_semitones < 0:
        new_root_semitones += 12
    
    # Find new root note
    reverse_map = {v: k for k, v in chord_map.items()}
    new_root = reverse_map[new_root_semitones]
    
    # Replace the root in the chord
    return chord.replace(root, new_root, 1)

def transpose_line(line, semitones):
    if semitones == 0:
        return line
    
    # Split by pipes and transpose chords
    parts = line.split('|')
    transposed_parts = []
    
    for part in parts:
        # Find chord patterns and transpose them, but preserve special characters
        chord_pattern = r'&?[A-G][#b]?[^|\s]*'
        transposed_part = re.sub(chord_pattern, lambda m: transpose_chord(m.group(), semitones), part)
        transposed_parts.append(transposed_part)
    
    return '|'.join(transposed_parts)

# Read input
song_file = '$song_file'
transpose = int('$transpose')

with open(song_file, 'r') as f:
    lines = f.readlines()

with open('$TEMP_DIR/$song_file', 'w') as f:
    for line in lines:
        transposed_line = transpose_line(line.rstrip(), transpose)
        f.write(transposed_line + '\\n')

print('  ✓ Transposed and copied')
" </dev/null

done < "$CONCERT_FILE"

echo ""
echo "Concert preparation complete!"
echo "Temp directory: $TEMP_DIR"
echo ""
echo "To use during the show:"
echo "  cd $TEMP_DIR"
echo "  # Open your editor here"
echo ""
echo "To clean up after the show:"
echo "  rm -rf $TEMP_DIR"
