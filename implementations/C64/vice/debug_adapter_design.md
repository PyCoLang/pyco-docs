# PyCo VS Code Debugger Design

Design document for the debugger component of the PyCo VS Code extension. The goal: source-level debugging with VICE emulator.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         VS Code                                 │
│  ┌─────────────┐    ┌───────────────────────────────────────┐   │
│  │ PyCo Source │    │        Debug UI                       │   │
│  │   Editor    │    │  (breakpoints, variables, call stack) │   │
│  └─────────────┘    └───────────────────────────────────────┘   │
│         │                           │                           │
│         │                    Debug Adapter                      │
│         │                     Protocol                          │
│         │                           │                           │
│  ┌──────┴───────────────────────────┴──────────────────────┐    │
│  │              PyCo Debug Adapter (TypeScript)            │    │
│  │  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐   │    │
│  │  │   Source    │  │    VICE      │  │   Variable    │   │    │
│  │  │   Mapper    │  │    Client    │  │   Manager     │   │    │
│  │  └─────────────┘  └──────────────┘  └───────────────┘   │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              │
                    TCP (Binary Protocol)
                        Port 6502
                              │
                    ┌─────────┴─────────┐
                    │   VICE Emulator   │
                    │  (x64sc -binary   │
                    │    monitor)       │
                    └───────────────────┘
```

## VICE Management Strategy

### Unified Approach

The extension manages a single VICE instance for both Run and Debug modes. We use the binary monitor protocol (port 6502) in both cases.

```
┌──────────────────────────────────────────────────────────────┐
│  VS Code Extension                                           │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │              ViceManager (shared component)            │  │
│  │                                                        │  │
│  │  1. Need to compile? (is source newer than PRG?)       │  │
│  │  2. VICE running? → connect : start + wait             │  │
│  │  3. Program load (autostart command)                   │  │
│  └────────────────────────────────────────────────────────┘  │
│                │                              │               │
│    [▶ Run Without Debug]            [▶ Start Debugging]      │
│         Ctrl+F5                            F5                 │
│                │                              │               │
│    - pycoc compile               - pycoc compile --debug     │
│    - autostart + exit            - autostart                 │
│    - VICE continues running      - set breakpoints           │
│                                  - stopped on entry/BP       │
└──────────────────────────────────────────────────────────────┘
```

### ViceManager Implementation

```typescript
class ViceManager {
    private viceProcess: ChildProcess | null = null;
    private viceClient: ViceClient;

    /**
     * Ensure VICE connection - starts if needed, waits until available
     */
    async ensureViceRunning(): Promise<void> {
        // Already running and connected?
        if (await this.viceClient.tryConnect()) {
            return;
        }

        // Start
        this.viceProcess = spawn(this.vicePath, [
            '-binarymonitor',
            '-binarymonitoraddress', '127.0.0.1:6502',
            '+confirmexit',      // Don't ask on exit
            '-autostartprgmode', '1'  // Autostart: inject to RAM
        ]);

        // Wait for port (avoiding race condition)
        const maxRetries = 50;
        for (let i = 0; i < maxRetries; i++) {
            await sleep(100);  // 100ms
            if (await this.viceClient.tryConnect()) {
                return;
            }
        }
        throw new Error('VICE failed to start within 5 seconds');
    }

    /**
     * Run program - shared logic for Run and Debug modes
     */
    async runProgram(pycoFile: string, debugMode: boolean): Promise<void> {
        const prgFile = pycoFile.replace('.pyco', '.prg');

        // 1. Compile if needed
        if (await this.needsRecompile(pycoFile, prgFile)) {
            const debugFlag = debugMode ? '--debug' : '';
            await exec(`pycoc compile ${debugFlag} "${pycoFile}"`);
        }

        // 2. Ensure VICE
        await this.ensureViceRunning();

        // 3. Load program
        await this.viceClient.autostart(prgFile);

        // 4. Debug vs Run difference
        if (!debugMode) {
            // Run: simply continue
            await this.viceClient.exit();
        }
        // Debug: caller sets breakpoints and handles stopped events
    }

    /**
     * Check if recompilation is needed
     */
    private async needsRecompile(source: string, target: string): Promise<boolean> {
        try {
            const sourceStat = await fs.stat(source);
            const targetStat = await fs.stat(target);
            return sourceStat.mtimeMs > targetStat.mtimeMs;
        } catch {
            return true;  // If target doesn't exist
        }
    }
}
```

### Race Condition Handling

There is a small delay between VICE starting and the TCP port being opened. The `ensureViceRunning()` handles this with a retry loop:

```
Timeline:
─────────────────────────────────────────────────────────────
0ms      spawn('x64sc', [...])     VICE process starts
~50ms    VICE initializes          GUI loading
~200ms   Binary monitor ready      Port 6502 listening
─────────────────────────────────────────────────────────────
         ↑
         tryConnect() retry loop (max 5 sec, 100ms interval)
```

### pycoc run vs Extension

| Aspect      | pycoc run (CLI) | Extension   |
|-------------|-----------------|-------------|
| Usage       | From terminal   | From VS Code |
| Monitor     | Text (6510)     | Binary (6502) |
| Debug support | None          | Yes         |
| VICE management | Own logic   | ViceManager |

The `pycoc run` command **remains** for CLI usage, but from VS Code the extension manages VICE directly.

## Components

### 1. Debug Adapter (src/debugger/debug-adapter.ts)

VS Code Debug Adapter Protocol (DAP) implementation.

```typescript
import {
    DebugSession,
    InitializedEvent,
    StoppedEvent,
    BreakpointEvent,
    OutputEvent,
    TerminatedEvent
} from '@vscode/debugadapter';

class PyCoDebugSession extends DebugSession {
    private sourceMapper: SourceMapper;
    private viceClient: ViceClient;
    private variableManager: VariableManager;

    // DAP request handling
    protected initializeRequest(response, args);
    protected launchRequest(response, args);
    protected attachRequest(response, args);
    protected setBreakPointsRequest(response, args);
    protected continueRequest(response, args);
    protected nextRequest(response, args);      // step over
    protected stepInRequest(response, args);    // step into
    protected stepOutRequest(response, args);   // step out
    protected pauseRequest(response, args);
    protected stackTraceRequest(response, args);
    protected scopesRequest(response, args);
    protected variablesRequest(response, args);
    protected evaluateRequest(response, args);
}
```

### 2. VICE Client (src/debugger/vice-client.ts)

TCP connection and binary protocol implementation.

```typescript
class ViceClient extends EventEmitter {
    private socket: net.Socket;
    private requestId: number = 0;
    private pendingRequests: Map<number, PendingRequest>;
    private responseBuffer: Buffer;

    // Connection management
    async connect(host: string, port: number): Promise<void>;
    async disconnect(): Promise<void>;

    // Command sending
    async memoryGet(start: number, end: number): Promise<Buffer>;
    async memorySet(address: number, data: Buffer): Promise<void>;
    async checkpointSet(address: number, type: CpuOperation): Promise<number>;
    async checkpointDelete(id: number): Promise<void>;
    async registersGet(): Promise<Registers>;
    async registersSet(regs: Partial<Registers>): Promise<void>;
    async step(count: number, stepOver: boolean): Promise<void>;
    async continue(): Promise<void>;
    async reset(hard: boolean): Promise<void>;

    // Events
    on(event: 'stopped', listener: (pc: number) => void): this;
    on(event: 'resumed', listener: () => void): this;
    on(event: 'disconnected', listener: () => void): this;
}
```

#### Binary Protocol Implementation

```typescript
private buildCommand(type: CommandType, body: Buffer): Buffer {
    const header = Buffer.alloc(11);
    header.writeUInt8(0x02, 0);                    // STX
    header.writeUInt8(0x02, 1);                    // API version
    header.writeUInt32LE(body.length, 2);          // Body length
    header.writeUInt32LE(this.requestId++, 6);     // Request ID
    header.writeUInt8(type, 10);                   // Command type
    return Buffer.concat([header, body]);
}

private parseResponse(data: Buffer): Response {
    return {
        apiVersion: data.readUInt8(1),
        bodyLength: data.readUInt32LE(2),
        type: data.readUInt8(6),
        error: data.readUInt8(7),
        requestId: data.readUInt32LE(8),
        body: data.slice(12)
    };
}
```

### 3. Source Mapper (src/debugger/source-mapper.ts)

PyCo source code ↔ assembly address mapping.

```typescript
interface SourceLocation {
    file: string;
    line: number;
    column?: number;
}

interface AddressMapping {
    address: number;        // 6502 address
    source: SourceLocation; // PyCo source position
    asmLine?: number;       // Assembly line (optional)
    label?: string;         // Label (if any)
}

class SourceMapper {
    private mappings: AddressMapping[] = [];
    private labelMap: Map<string, number> = new Map();

    // Load debug info
    loadFromDebugFile(debugFile: string): void;
    loadFromLabelFile(labelFile: string): void;

    // Mappings
    getSourceLocation(address: number): SourceLocation | undefined;
    getAddress(file: string, line: number): number | undefined;
    getLabel(address: number): string | undefined;
    getLabelAddress(label: string): number | undefined;
}
```

### 4. Variable Manager (src/debugger/variable-manager.ts)

Display PyCo variables in the debug UI.

```typescript
interface PyCoVariable {
    name: string;
    type: string;           // byte, word, int, float, etc.
    address: number;        // Memory address
    size: number;           // Size in bytes
    scope: 'global' | 'local' | 'parameter';
    frameOffset?: number;   // Stack offset (local/param)
}

class VariableManager {
    private variables: Map<string, PyCoVariable> = new Map();

    // Load variable definitions (from debug info)
    loadVariables(debugInfo: DebugInfo): void;

    // Read value
    async getValue(variable: PyCoVariable, viceClient: ViceClient): Promise<string>;
    async getLocalValue(name: string, fp: number, viceClient: ViceClient): Promise<string>;

    // Format by type
    formatValue(data: Buffer, type: string): string;
}
```

## Debug Info Format

The PyCo compiler should generate a debug info file during compilation.

### Proposed Format: JSON

```json
{
    "version": 1,
    "sourceFile": "game.pyco",
    "outputFile": "game.prg",
    "entryPoint": "0x080d",
    "mappings": [
        {
            "address": "0x080d",
            "source": { "file": "game.pyco", "line": 5, "column": 0 },
            "label": "__F_main"
        },
        {
            "address": "0x0820",
            "source": { "file": "game.pyco", "line": 6, "column": 4 }
        }
    ],
    "variables": [
        {
            "name": "score",
            "type": "word",
            "address": "0x0900",
            "scope": "global"
        },
        {
            "name": "x",
            "type": "byte",
            "frameOffset": 0,
            "scope": "local",
            "function": "main"
        }
    ],
    "functions": [
        {
            "name": "main",
            "label": "__F_main",
            "startAddress": "0x080d",
            "endAddress": "0x0850",
            "frameSize": 4,
            "parameters": [],
            "locals": [
                { "name": "x", "type": "byte", "offset": 0 },
                { "name": "y", "type": "byte", "offset": 1 }
            ]
        }
    ],
    "labels": {
        "__F_main": "0x080d",
        "__B_score": "0x0900"
    }
}
```

### VICE Label File Generation

The compiler should also generate a `.vs` file for VICE compatibility:

```
al C:080d .__F_main
al C:0900 .__B_score
al C:0820 .main_loop
```

## VS Code Integration

### launch.json Configuration

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "pyco",
            "request": "launch",
            "name": "Debug PyCo Program",
            "program": "${workspaceFolder}/game.pyco",
            "vice": {
                "path": "/usr/local/bin/x64sc",
                "port": 6502,
                "args": ["-warp"]
            },
            "stopOnEntry": true
        },
        {
            "type": "pyco",
            "request": "attach",
            "name": "Attach to VICE",
            "port": 6502,
            "program": "${workspaceFolder}/game.pyco"
        }
    ]
}
```

### package.json Additions

```json
{
    "contributes": {
        "debuggers": [
            {
                "type": "pyco",
                "label": "PyCo Debug",
                "program": "./out/debugger/debug-adapter.js",
                "runtime": "node",
                "configurationAttributes": {
                    "launch": {
                        "required": ["program"],
                        "properties": {
                            "program": {
                                "type": "string",
                                "description": "PyCo source file"
                            },
                            "vice": {
                                "type": "object",
                                "properties": {
                                    "path": { "type": "string" },
                                    "port": { "type": "number", "default": 6502 }
                                }
                            },
                            "stopOnEntry": { "type": "boolean", "default": true }
                        }
                    },
                    "attach": {
                        "required": ["port"],
                        "properties": {
                            "port": { "type": "number", "default": 6502 },
                            "program": { "type": "string" }
                        }
                    }
                }
            }
        ],
        "breakpoints": [
            { "language": "pyco" }
        ]
    }
}
```

## Implementation Phases

### Phase 1: Basic Debugging

1. **VICE connection** - TCP client for binary protocol
2. **Launch/Attach** - Start VICE or connect to existing
3. **Breakpoints** - Source line → address mapping
4. **Step commands** - Step in, step over, continue
5. **Registers** - Display CPU registers

### Phase 2: Variable Inspection

1. **Global variables** - BSS segment variables
2. **Local variables** - Stack frame based access
3. **Watch expressions** - Arbitrary memory watching

### Phase 3: Advanced Features

1. **Call stack** - JSR/RTS tracking
2. **Conditional breakpoints** - VICE condition syntax
3. **Memory view** - Hex dump panel
4. **Disassembly view** - Assembly alongside PyCo source

## Compiler Support (Implemented ✅)

### Debug Info Generation

Debug info is **always** generated during compilation, there's no separate flag:

```bash
pycoc compile game.pyco

# Output files:
# - build/game.prg    (program)
# - build/game.asm    (assembly source)
# - build/game.dbg    (JSON debug info)
```

### Debug Info Format (.dbg)

The assembler generates the `.dbg` file, which contains the actual memory addresses:

```json
{
  "version": 1,
  "labels": {
    "__F_main": "080e",
    "__B_score": "0900",
    "__R_PRINT_BYTE": "0a50"
  },
  "mappings": [
    {"addr": "081b", "file": "game.pyco", "line": 10},
    {"addr": "0825", "file": "game.pyco", "line": 14}
  ]
}
```

### Implementation

1. **CodeGenerator** (`generator.py`) - Generates `__SRC_filename_pyco_LINE` labels at each PyCo line
2. **Assembler** (`assembler/codegen.py`) - `get_debug_info()` method extracts label addresses
3. **CLI** (`cli.py`) - `assemble_with_debug()` call and `.dbg` file writing

## Reference Implementations

- **[VS64](https://github.com/rolandshacks/vs64)** - Full C64 dev environment
- **[vscode-cc65-vice-debug](https://github.com/empathicqubit/vscode-cc65-vice-debug)** - CC65 debugger
- **[IceBro Lite](https://github.com/Sakrac/IceBroLite)** - Standalone 6502 debugger

## Testing Strategy

### Unit Tests

1. Binary protocol encoder/decoder
2. Source mapper lookup
3. Variable formatter

### Integration Tests

1. VICE connection lifecycle
2. Breakpoint set/hit/delete
3. Step operations
4. Memory read/write

### E2E Tests

1. Complete debug session workflow
2. Multiple breakpoint handling
3. Variable inspection with different types
