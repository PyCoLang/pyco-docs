# PyCo VS Code Debugger Design

A PyCo VS Code extension debugger komponensének tervezési dokumentuma. A cél: source-level debugging VICE emulátorral.

## Architektúra áttekintés

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

## VICE kezelési stratégia

### Egységesített megközelítés

Az extension egyetlen VICE instance-t kezel mind Run, mind Debug módban. A binary monitor protokollt (port 6502) használjuk mindkét esetben.

```
┌──────────────────────────────────────────────────────────────┐
│  VS Code Extension                                           │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │              ViceManager (közös komponens)             │  │
│  │                                                        │  │
│  │  1. Kell-e compile? (source újabb mint PRG?)           │  │
│  │  2. VICE fut? → csatlakozás : indítás + várakozás      │  │
│  │  3. Program betöltés (autostart parancs)               │  │
│  └────────────────────────────────────────────────────────┘  │
│                │                              │               │
│    [▶ Run Without Debug]            [▶ Start Debugging]      │
│         Ctrl+F5                            F5                 │
│                │                              │               │
│    - pycoc compile               - pycoc compile --debug     │
│    - autostart + exit            - autostart                 │
│    - VICE fut tovább             - breakpoints beállítása    │
│                                  - stopped on entry/BP       │
└──────────────────────────────────────────────────────────────┘
```

### ViceManager implementáció

```typescript
class ViceManager {
    private viceProcess: ChildProcess | null = null;
    private viceClient: ViceClient;

    /**
     * VICE kapcsolat biztosítása - indít ha kell, vár amíg elérhető
     */
    async ensureViceRunning(): Promise<void> {
        // Már fut és csatlakozva?
        if (await this.viceClient.tryConnect()) {
            return;
        }

        // Indítás
        this.viceProcess = spawn(this.vicePath, [
            '-binarymonitor',
            '-binarymonitoraddress', '127.0.0.1:6502',
            '+confirmexit',      // Ne kérdezzen kilépéskor
            '-autostartprgmode', '1'  // Autostart: inject to RAM
        ]);

        // Várakozás a portra (race condition elkerülése)
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
     * Program futtatása - közös logika Run és Debug módhoz
     */
    async runProgram(pycoFile: string, debugMode: boolean): Promise<void> {
        const prgFile = pycoFile.replace('.pyco', '.prg');

        // 1. Compile ha szükséges
        if (await this.needsRecompile(pycoFile, prgFile)) {
            const debugFlag = debugMode ? '--debug' : '';
            await exec(`pycoc compile ${debugFlag} "${pycoFile}"`);
        }

        // 2. VICE biztosítása
        await this.ensureViceRunning();

        // 3. Program betöltés
        await this.viceClient.autostart(prgFile);

        // 4. Debug vs Run különbség
        if (!debugMode) {
            // Run: egyszerűen folytatás
            await this.viceClient.exit();
        }
        // Debug: a hívó állítja be a breakpointokat és kezeli a stopped eventeket
    }

    /**
     * Ellenőrzi, hogy kell-e újrafordítani
     */
    private async needsRecompile(source: string, target: string): Promise<boolean> {
        try {
            const sourceStat = await fs.stat(source);
            const targetStat = await fs.stat(target);
            return sourceStat.mtimeMs > targetStat.mtimeMs;
        } catch {
            return true;  // Ha a target nem létezik
        }
    }
}
```

### Race condition kezelése

A VICE indítása és a TCP port megnyitása között van egy kis késleltetés. A `ensureViceRunning()` retry loop-pal kezeli ezt:

```
Idővonal:
─────────────────────────────────────────────────────────────
0ms      spawn('x64sc', [...])     VICE process indul
~50ms    VICE inicializál          GUI betöltése
~200ms   Binary monitor ready      Port 6502 figyel
─────────────────────────────────────────────────────────────
         ↑
         tryConnect() retry loop (max 5 sec, 100ms intervallumon)
```

### pycoc run vs Extension

| Aspektus | pycoc run (CLI) | Extension |
|----------|-----------------|-----------|
| Használat | Terminálból | VS Code-ból |
| Monitor | Text (6510) | Binary (6502) |
| Debug támogatás | Nincs | Van |
| VICE kezelés | Saját logika | ViceManager |

A `pycoc run` parancs **megmarad** CLI használatra, de VS Code-ból az extension kezeli a VICE-t közvetlenül.

## Komponensek

### 1. Debug Adapter (src/debugger/debug-adapter.ts)

VS Code Debug Adapter Protocol (DAP) implementáció.

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

    // DAP kérések kezelése
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

TCP kapcsolat és bináris protokoll implementáció.

```typescript
class ViceClient extends EventEmitter {
    private socket: net.Socket;
    private requestId: number = 0;
    private pendingRequests: Map<number, PendingRequest>;
    private responseBuffer: Buffer;

    // Kapcsolat kezelés
    async connect(host: string, port: number): Promise<void>;
    async disconnect(): Promise<void>;

    // Parancsok küldése
    async memoryGet(start: number, end: number): Promise<Buffer>;
    async memorySet(address: number, data: Buffer): Promise<void>;
    async checkpointSet(address: number, type: CpuOperation): Promise<number>;
    async checkpointDelete(id: number): Promise<void>;
    async registersGet(): Promise<Registers>;
    async registersSet(regs: Partial<Registers>): Promise<void>;
    async step(count: number, stepOver: boolean): Promise<void>;
    async continue(): Promise<void>;
    async reset(hard: boolean): Promise<void>;

    // Események
    on(event: 'stopped', listener: (pc: number) => void): this;
    on(event: 'resumed', listener: () => void): this;
    on(event: 'disconnected', listener: () => void): this;
}
```

#### Bináris protokoll implementáció

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

PyCo forráskód ↔ assembly cím leképezés.

```typescript
interface SourceLocation {
    file: string;
    line: number;
    column?: number;
}

interface AddressMapping {
    address: number;        // 6502 cím
    source: SourceLocation; // PyCo forrás pozíció
    asmLine?: number;       // Assembly sor (opcionális)
    label?: string;         // Címke (ha van)
}

class SourceMapper {
    private mappings: AddressMapping[] = [];
    private labelMap: Map<string, number> = new Map();

    // Debug info betöltése
    loadFromDebugFile(debugFile: string): void;
    loadFromLabelFile(labelFile: string): void;

    // Leképezések
    getSourceLocation(address: number): SourceLocation | undefined;
    getAddress(file: string, line: number): number | undefined;
    getLabel(address: number): string | undefined;
    getLabelAddress(label: string): number | undefined;
}
```

### 4. Variable Manager (src/debugger/variable-manager.ts)

PyCo változók megjelenítése a debug UI-ban.

```typescript
interface PyCoVariable {
    name: string;
    type: string;           // byte, word, int, float, etc.
    address: number;        // Memória cím
    size: number;           // Méret bájtokban
    scope: 'global' | 'local' | 'parameter';
    frameOffset?: number;   // Stack offset (local/param)
}

class VariableManager {
    private variables: Map<string, PyCoVariable> = new Map();

    // Változó definíciók betöltése (debug info-ból)
    loadVariables(debugInfo: DebugInfo): void;

    // Érték olvasás
    async getValue(variable: PyCoVariable, viceClient: ViceClient): Promise<string>;
    async getLocalValue(name: string, fp: number, viceClient: ViceClient): Promise<string>;

    // Formázás típus szerint
    formatValue(data: Buffer, type: string): string;
}
```

## Debug Info formátum

A PyCo compiler generáljon debug info fájlt fordításkor.

### Javasolt formátum: JSON

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

### VICE Label fájl generálás

A compiler generáljon `.vs` fájlt is VICE kompatibilitáshoz:

```
al C:080d .__F_main
al C:0900 .__B_score
al C:0820 .main_loop
```

## VS Code integráció

### launch.json konfiguráció

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

### package.json kiegészítések

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

## Implementációs fázisok

### Fázis 1: Alapvető debugging

1. **VICE kapcsolat** - TCP kliens a bináris protokollhoz
2. **Launch/Attach** - VICE indítása vagy csatlakozás
3. **Breakpoint-ok** - Source line → address mapping
4. **Step parancsok** - Step in, step over, continue
5. **Regiszterek** - CPU regiszterek megjelenítése

### Fázis 2: Variable inspection

1. **Global változók** - BSS szegmens változók
2. **Local változók** - Stack frame alapú elérés
3. **Watch expressions** - Tetszőleges memória figyelés

### Fázis 3: Advanced features

1. **Call stack** - JSR/RTS tracking
2. **Conditional breakpoints** - VICE condition syntax
3. **Memory view** - Hex dump panel
4. **Disassembly view** - Assembly mellett PyCo source

## Compiler támogatás (Implementálva ✅)

### Debug info generálás

A debug info **mindig** generálódik fordításkor, nincs külön flag:

```bash
pycoc compile game.pyco

# Kimeneti fájlok:
# - build/game.prg    (program)
# - build/game.asm    (assembly forrás)
# - build/game.dbg    (JSON debug info)
```

### Debug info formátum (.dbg)

Az assembler generálja a `.dbg` fájlt, amely tartalmazza a valós memóriacímeket:

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

### Implementáció

1. **CodeGenerator** (`generator.py`) - `__SRC_filename_pyco_LINE` label-eket generál minden PyCo sornál
2. **Assembler** (`assembler/codegen.py`) - `get_debug_info()` metódus kinyeri a label címeket
3. **CLI** (`cli.py`) - `assemble_with_debug()` hívás és `.dbg` fájl írás

## Referencia implementációk

- **[VS64](https://github.com/rolandshacks/vs64)** - Full C64 dev environment
- **[vscode-cc65-vice-debug](https://github.com/empathicqubit/vscode-cc65-vice-debug)** - CC65 debugger
- **[IceBro Lite](https://github.com/Sakrac/IceBroLite)** - Standalone 6502 debugger

## Tesztelési stratégia

### Unit tesztek

1. Bináris protokoll encoder/decoder
2. Source mapper lookup
3. Variable formatter

### Integration tesztek

1. VICE kapcsolat lifecycle
2. Breakpoint set/hit/delete
3. Step műveletek
4. Memória olvasás/írás

### E2E tesztek

1. Teljes debug session workflow
2. Több breakpoint kezelése
3. Variable inspection különböző típusokkal
