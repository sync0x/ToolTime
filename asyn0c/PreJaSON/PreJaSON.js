/**
 * P-JSON (Predicate-JSON) Codec
 * Implements the grammar defined by structural recursion.
 * * Glyphs:
 * ⟦ (\u27E6) Object Start
 * ⟧ (\u27E7) Object End
 * ⟨ (\u27E8) Array Start
 * ⟩ (\u27E9) Array End
 * ∧ (\u2227) Conjunction (Separator)
 * ↦ (\u21A6) Mapping (Key-Value)
 * • (\u2022) Symbol Prefix
 * ⌜ (\u231C) String Start (Gödel Quote)
 * ⌝ (\u231D) String End (Gödel Quote)
 */

const GLYPHS = {
    OBJ_START: '\u27E6', // ⟦
    OBJ_END:   '\u27E7', // ⟧
    ARR_START: '\u27E8', // ⟨
    ARR_END:   '\u27E9', // ⟩
    AND:       '\u2227', // ∧
    MAP:       '\u21A6', // ↦
    BULLET:    '\u2022', // •
    STR_START: '\u231C', // ⌜
    STR_END:   '\u231D'  // ⌝
};

let breakSUB = 0x1A;  // ASCII SUB (Substitute): next char is literal
let breakESC = 0x1B;  // ASCII ESC (Escape): next char literal after subtracting 0x40

const ATOMS = {
    TRUE:  "go'i",
    FALSE: "nago'i",
    NULL:  "noda"
};

class PJSON {

    /**
     * Encodes a JavaScript Object/Value into P-JSON format.
     * @param {any} x 
     * @returns {string}
     */
    static encode(x) {
        // Atomic: Null
        if (x === null) return ATOMS.NULL;

        // Atomic: Booleans
        if (typeof x === 'boolean') return x ? ATOMS.TRUE : ATOMS.FALSE;

        // Atomic: Numbers
        if (typeof x === 'number') return String(x);

        // Atomic: Strings
        if (typeof x === 'string') {
            const escaped = PJSON.escapeString(x);
            return `${GLYPHS.STR_START}${escaped}${GLYPHS.STR_END}`;
        }

        // Sequence (Array)
        if (Array.isArray(x)) {
            if (x.length === 0) return `${GLYPHS.ARR_START}${GLYPHS.ARR_END}`;
            const elements = x.map(v => PJSON.encode(v));
            return `${GLYPHS.ARR_START} ${elements.join(` ${GLYPHS.AND} `)} ${GLYPHS.ARR_END}`;
        }

        // Hashtable (Object)
        if (typeof x === 'object') {
            const keys = Object.keys(x);
            if (keys.length === 0) return `${GLYPHS.OBJ_START}${GLYPHS.OBJ_END}`;
            
            const pairs = keys.map(k => {
                const escapedKey = PJSON.escapeString(k);
                const encodedKey = `${GLYPHS.STR_START}${escapedKey}${GLYPHS.STR_END}`;
                const encodedVal = PJSON.encode(x[k]);
                return `${GLYPHS.BULLET}${encodedKey} ${GLYPHS.MAP} ${encodedVal}`;
            });

            return `${GLYPHS.OBJ_START} ${pairs.join(` ${GLYPHS.AND} `)} ${GLYPHS.OBJ_END}`;
        }

        throw new Error(`Unsupported type for P-JSON encoding: ${typeof x}`);
    }

    /**
     * Escapes reserved glyphs and control characters in a string using SUB prefix.
     * @param {string} str 
     * @returns {string}
     */
    static escapeString(str) {
        const reservedChars = Object.values(GLYPHS);
        let result = "";
        
        for (const char of str) {
            if (reservedChars.includes(char) || char.charCodeAt(0) === breakSUB || char.charCodeAt(0) === breakESC) {
                result += String.fromCharCode(breakSUB) + char;
            } else {
                result += char;
            }
        }
        
        return result;
    }

    /**
     * Decodes a P-JSON string back into a JavaScript Object/Value.
     * @param {string} str 
     * @returns {any}
     */
    static decode(str) {
        const tokens = PJSON.tokenize(str);
        const parser = new Parser(tokens);
        return parser.parse();
    }

    /**
     * Generator that yields tokens from the input string.
     * @param {string} input 
     */
    static *tokenize(input) {
        let i = 0;
        const length = input.length;

        while (i < length) {
            const char = input[i];
            const charCode = char.charCodeAt(0);

            // Skip whitespace
            if (/\s/.test(char)) {
                i++;
                continue;
            }

            // Handle escape sequences
            if (charCode === breakSUB) {
                // SUB: next character is literal
                i++;
                if (i >= length) throw new Error("Unexpected end of input after SUB escape");
                const escapedChar = input[i];
                // Return as a GLYPH if it's normally a glyph, otherwise as part of context
                if (Object.values(GLYPHS).includes(escapedChar)) {
                    yield { type: 'ESCAPED_GLYPH', value: escapedChar };
                } else {
                    yield { type: 'ESCAPED_CHAR', value: escapedChar };
                }
                i++;
                continue;
            }

            if (charCode === breakESC) {
                // ESC: next character is literal after subtracting 0x40
                i++;
                if (i >= length) throw new Error("Unexpected end of input after ESC escape");
                const nextChar = input[i];
                const nextCode = nextChar.charCodeAt(0);
                const unescapedCode = nextCode - 0x40;
                const unescapedChar = String.fromCharCode(unescapedCode);
                yield { type: 'ESCAPED_CHAR', value: unescapedChar };
                i++;
                continue;
            }

            // Structural Glyphs
            if (Object.values(GLYPHS).includes(char)) {
                // If it's a String Start, consume until String End (handling escapes)
                if (char === GLYPHS.STR_START) {
                    let val = "";
                    i++; // Skip start quote
                    while (i < length) {
                        const curr = input[i];
                        const currCode = curr.charCodeAt(0);

                        // Handle SUB escape within string
                        if (currCode === breakSUB) {
                            i++;
                            if (i >= length) throw new Error("Unterminated Gödel string literal (SUB at end)");
                            val += input[i];
                            i++;
                            continue;
                        }

                        // Handle ESC escape within string
                        if (currCode === breakESC) {
                            i++;
                            if (i >= length) throw new Error("Unterminated Gödel string literal (ESC at end)");
                            const nextCurr = input[i];
                            const nextCurrCode = nextCurr.charCodeAt(0);
                            const unescapedCode = nextCurrCode - 0x40;
                            val += String.fromCharCode(unescapedCode);
                            i++;
                            continue;
                        }

                        // String end marker
                        if (curr === GLYPHS.STR_END) {
                            break;
                        }

                        val += curr;
                        i++;
                    }
                    if (i >= length) throw new Error("Unterminated Gödel string literal");
                    i++; // Skip end quote
                    yield { type: 'STRING', value: val };
                } else {
                    yield { type: 'GLYPH', value: char };
                    i++;
                }
                continue;
            }

            // Lojban Atoms & Numbers
            // We read until we hit whitespace or a glyph
            let buffer = "";
            while (i < length) {
                const peek = input[i];
                const peekCode = peek.charCodeAt(0);
                if (/\s/.test(peek) || Object.values(GLYPHS).includes(peek) || peekCode === breakSUB || peekCode === breakESC) {
                    break;
                }
                buffer += peek;
                i++;
            }

            if (buffer === ATOMS.TRUE) yield { type: 'BOOL', value: true };
            else if (buffer === ATOMS.FALSE) yield { type: 'BOOL', value: false };
            else if (buffer === ATOMS.NULL) yield { type: 'NULL', value: null };
            else if (!isNaN(Number(buffer))) yield { type: 'NUMBER', value: Number(buffer) };
            else throw new Error(`Unexpected token: ${buffer}`);
        }
    }
}

/**
 * Recursive Descent Parser Helper
 */
class Parser {
    constructor(tokenGenerator) {
        this.tokens = tokenGenerator;
        this.current = this.tokens.next();
    }

    peek() {
        return this.current;
    }

    consume(expectedType = null, expectedValue = null) {
        const token = this.current;
        if (token.done) throw new Error("Unexpected end of input");
        
        if (expectedType && token.value.type !== expectedType) {
            throw new Error(`Expected type ${expectedType}, got ${token.value.type}`);
        }
        if (expectedValue && token.value.value !== expectedValue) {
            throw new Error(`Expected value '${expectedValue}', got '${token.value.value}'`);
        }

        this.current = this.tokens.next();
        return token.value;
    }

    parse() {
        const token = this.peek();
        if (token.done) throw new Error("Unexpected end of input");

        const t = token.value;

        // Atomic: Strings, Numbers, Bools, Null
        if (t.type === 'STRING') return this.consume().value;
        if (t.type === 'NUMBER') return this.consume().value;
        if (t.type === 'BOOL') return this.consume().value;
        if (t.type === 'NULL') { this.consume(); return null; }
        if (t.type === 'ESCAPED_CHAR') return this.consume().value;

        // Sequence: Array ⟨ ... ⟩
        if (t.type === 'GLYPH' && t.value === GLYPHS.ARR_START) {
            return this.parseArray();
        }

        // Hashtable: Object ⟦ ... ⟧
        if (t.type === 'GLYPH' && t.value === GLYPHS.OBJ_START) {
            return this.parseObject();
        }

        throw new Error(`Unexpected token at start of expression: ${JSON.stringify(t)}`);
    }

    parseArray() {
        this.consume('GLYPH', GLYPHS.ARR_START);
        const result = [];

        // Check for empty array
        let next = this.peek();
        if (!next.done && next.value.type === 'GLYPH' && next.value.value === GLYPHS.ARR_END) {
            this.consume();
            return result;
        }

        // Element Loop
        while (true) {
            result.push(this.parse());

            next = this.peek();
            if (next.done) throw new Error("Unterminated Array");

            if (next.value.type === 'GLYPH' && next.value.value === GLYPHS.AND) {
                this.consume(); // Consume AND separator
                continue;
            } else if (next.value.type === 'GLYPH' && next.value.value === GLYPHS.ARR_END) {
                this.consume(); // Consume End Bracket
                break;
            } else {
                throw new Error(`Expected ∧ or ⟩ in array, got ${next.value.value}`);
            }
        }
        return result;
    }

    parseObject() {
        this.consume('GLYPH', GLYPHS.OBJ_START);
        const result = {};

        // Check for empty object
        let next = this.peek();
        if (!next.done && next.value.type === 'GLYPH' && next.value.value === GLYPHS.OBJ_END) {
            this.consume();
            return result;
        }

        // Pair Loop
        while (true) {
            // Pair structure: •⌜key⌝ ↦ value
            this.consume('GLYPH', GLYPHS.BULLET);
            const keyToken = this.consume('STRING');
            this.consume('GLYPH', GLYPHS.MAP);
            const value = this.parse();

            result[keyToken.value] = value;

            next = this.peek();
            if (next.done) throw new Error("Unterminated Object");

            if (next.value.type === 'GLYPH' && next.value.value === GLYPHS.AND) {
                this.consume(); // Consume AND separator
                continue;
            } else if (next.value.type === 'GLYPH' && next.value.value === GLYPHS.OBJ_END) {
                this.consume(); // Consume End Bracket
                break;
            } else {
                throw new Error(`Expected ∧ or ⟧ in object, got ${next.value.value}`);
            }
        }
        return result;
    }
}

// --- Usage Example ---

const data = {
    "system": "Lazarus",
    "ide_ready": true,
    "remote_deploy": false,
    "error_log": null,
    "parameters": [1.0, 1.5, 2025],
    "config": {
        "host": "127.0.0.1",
        "port": 8080
    }
};

console.log("--- Original Data ---");
console.log(JSON.stringify(data, null, 2));

console.log("\n--- Encoded P-JSON ---");
const encoded = PJSON.encode(data);
console.log(encoded);

console.log("\n--- Decoded Data ---");
const decoded = PJSON.decode(encoded);
console.log(JSON.stringify(decoded, null, 2));

// Export for module usage
module.exports = { PJSON };
