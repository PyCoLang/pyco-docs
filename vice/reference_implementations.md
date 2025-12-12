# VICE Debugger Reference Implementations

Ez a dokumentum összefoglalja a létező VICE debugger implementációk tanulságait.

## Vizsgált projektek

| Projekt | Nyelv | GitHub | Fő tanulság |
|---------|-------|--------|-------------|
| VS64 | JavaScript | [rolandshacks/vs64](https://github.com/rolandshacks/vs64) | Referencia VS Code debugger |
| cc65-debugger | TypeScript | [empathicqubit/vscode-cc65-debugger](https://github.com/empathicqubit/vscode-cc65-debugger) | Jól strukturált protokoll kezelés |
| pyvicemon | Python | [Galfodo/pyvicemon](https://github.com/Galfodo/pyvicemon) | Tiszta protokoll implementáció |
| IceBro Lite | C++ | [Sakrac/IceBroLite](https://github.com/Sakrac/IceBroLite) | Standalone GUI debugger |

## VS64 - Kritikus tanulságok

### VICE indítási szekvencia

A VS64 a következő parancssoron indítja a VICE-t:

```bash
x64sc +remotemonitor -binarymonitor -binarymonitoraddress ip4://127.0.0.1:6502 -autostartprgmode 1
```

**Kritikus opciók:**
- `+remotemonitor` - Text monitor KIKAPCSOLÁSA (csak binary!)
- `-autostartprgmode 1` - PRG injektálása RAM-ba (nem autostart!)

### Program betöltési szekvencia

```javascript
// VS64 debug_vice.js - loadProgram() metódus
async loadProgram(filename) {
    await this.init();
    await this.cmdReset();                    // 1. RESET küldése!
    await this.cmdAutostart(filename, true);  // 2. Binary autostart
}
```

**KRITIKUS:** A RESET parancs küldése ELŐBB történik, mint az autostart!

### Debug session indítása

```
VS64 Initialization Sequence:
─────────────────────────────────────────────────────────────────
1. VICE spawn (üres, program nélkül!)
2. Socket connect (retry loop 250ms intervallumon)
3. cmdRegistersAvailable() - regiszter lista lekérése
4. cmdBanksAvailable() - memória bankok lekérése
5. loadProgram():
   a. cmdReset()
   b. cmdAutostart(filename)
6. setBreakpoints() - breakpointok beállítása
7. start() → cmdExit() - futás indítása
─────────────────────────────────────────────────────────────────
```

### Breakpoint kezelés

```javascript
// setBreakpoints() metódus
async setBreakpoints(breakpoints) {
    // 1. Meglévő checkpointok lekérése
    const existing = await this.cmdCheckpointList();

    // 2. Nem szükséges checkpointok törlése
    for (const cp of existing) {
        if (!breakpoints.find(bp => bp.address === cp.address)) {
            await this.cmdCheckpointDelete(cp.id);
        }
    }

    // 3. Új checkpointok létrehozása
    for (const bp of breakpoints) {
        if (!existing.find(cp => cp.address === bp.address)) {
            await this.cmdCheckpointSet(bp.address, bp.address, true, true, 0x04);
        }
    }
}
```

### Stopped event kezelés

```javascript
// RESPONSE_STOPPED (0x62) event feldolgozása
onStoppedEvent(response) {
    const pc = this.registers.pc;

    // Step mód: ellenőrizzük, hogy source sornál vagyunk-e
    if (this.stepMode) {
        const info = this.debugInfo.getAddressInfo(pc);
        if (!info || !info.line) {
            // Köztes kód - folytatjuk automatikusan
            this.cmdExit();
            return;
        }
    }

    // Breakpoint: melyik checkpoint?
    const checkpoint = this.findCheckpointAtAddress(pc);

    // DAP StoppedEvent küldése
    this.sendEvent('stopped', {
        reason: checkpoint ? 'breakpoint' : 'step',
        threadId: 1
    });
}
```

## cc65-debugger - Protokoll kezelés

### binary-dto.ts - Üzenettípusok

```typescript
// Command típusok
export enum CommandType {
    memoryGet = 0x01,
    memorySet = 0x02,
    checkpointSet = 0x12,
    checkpointDelete = 0x13,
    checkpointList = 0x14,
    checkpointToggle = 0x15,
    registersGet = 0x31,
    registersSet = 0x32,
    registersAvailable = 0x83,
    advanceInstructions = 0x71,
    executeUntilReturn = 0x73,
    ping = 0x81,
    exit = 0xbb,
    quit = 0xaa,
    reset = 0xcc,
    autostart = 0xdd,
}

// Response típusok
export enum ResponseType {
    stopped = 0x62,     // Emulator stopped (breakpoint, step)
    resumed = 0x63,     // Emulator resumed
    jam = 0x61,         // CPU JAM (illegal opcode)
    checkpointInfo = 0x11,  // Breakpoint hit info
}
```

### Aszinkron válaszkezelés

```typescript
// Request ID alapú válasz kezelés
class BinaryProtocol {
    private pendingRequests: Map<number, Promise>;
    private requestId: number = 0;

    async sendCommand(type: CommandType, body: Buffer): Promise<Response> {
        const id = this.requestId++;
        const promise = new Promise((resolve) => {
            this.pendingRequests.set(id, resolve);
        });

        this.socket.write(this.buildPacket(type, id, body));
        return promise;
    }

    onData(data: Buffer) {
        const response = this.parseResponse(data);

        // Event response (nincs request ID)
        if (response.type === ResponseType.stopped) {
            this.emit('stopped', response);
            return;
        }

        // Request válasz
        const resolver = this.pendingRequests.get(response.requestId);
        if (resolver) {
            resolver(response);
            this.pendingRequests.delete(response.requestId);
        }
    }
}
```

## pyvicemon - Python referencia

### Protokoll header formátum

```python
# Command header (11 bytes)
CMD_HEADER = [
    ('stx', uint8),           # 0x02
    ('api_version', uint8),   # 0x02
    ('body_size', uint32),    # Little-endian
    ('request_id', uint32),   # Little-endian
    ('command', uint8)
]

# Response header (12 bytes)
RESPONSE_HEADER = [
    ('stx', uint8),           # 0x02
    ('api_version', uint8),   # 0x02
    ('body_size', uint32),
    ('response_type', uint8),
    ('error_code', uint8),    # 0x00 = OK
    ('request_id', uint32)
]
```

### Event polling

```python
def wait_for_debugger_event(timeout=1.0):
    """Várakozás VICE eseményre (breakpoint, JAM, stb.)"""
    sock.settimeout(timeout)

    while True:
        try:
            data = sock.recv(4096)
            response = parse_response(data)

            if response.type == MON_RESPONSE_STOPPED:
                return response
            elif response.type == MON_RESPONSE_CHECKPOINT_INFO:
                # Breakpoint hit
                return response

        except socket.timeout:
            return None  # Nincs esemény
```

## Összehasonlítás: Mi volt rossz a PyCo megközelítésben

### Eredeti PyCo szekvencia (HIBÁS)

```
1. VICE indítása: x64sc -binarymonitor -autostart-delay 3 program.prg
2. Socket connect
3. Breakpoint beállítása
4. cmdExit() (continue)
```

**Problémák:**
1. A PRG parancssoron → VICE rögtön elkezdi az autostart-ot
2. A `-autostart-delay` késlelteti, de a VICE "stopped" állapotba kerül connect-kor
3. A program már túlment az entry pointon mire a breakpoint beáll

### Helyes szekvencia (VS64 alapján)

```
1. VICE indítása: x64sc -binarymonitor (PROGRAM NÉLKÜL!)
2. Socket connect
3. cmdReset()
4. cmdAutostart(program.prg, run=true)  # Binary protocol autostart
5. Breakpoint beállítása
6. cmdExit() (continue)
```

**Miért működik ez:**
1. VICE üres állapotban indul
2. Reset biztosítja a tiszta állapotot
3. Binary autostart betölti a programot DE MÉG NEM INDÍTJA (run=false esetén)
4. Breakpointok beállíthatók
5. Exit parancs indítja a programot

## Implementációs terv a PyCo-hoz

### 1. Módosítások a ViceManager-ben

```typescript
// vice-manager.ts

async debugProgram(prgFile: string, entryPointAddress?: number): Promise<void> {
    // 1. VICE indítása ÜRES állapotban
    await this.startViceEmpty();

    // 2. Várakozás a kapcsolatra
    await this.waitForConnection();

    // 3. Reset küldése (tiszta állapot)
    await this.viceClient.reset();

    // 4. Program betöltése binary autostart-tal
    await this.viceClient.autostart(prgFile, false);  // run=false!

    // 5. Entry breakpoint beállítása (ha van)
    if (entryPointAddress !== undefined) {
        await this.viceClient.checkpointSet(entryPointAddress, ...);
    }

    // 6. Futás indítása
    await this.viceClient.continue();
}

private async startViceEmpty(): Promise<void> {
    const args = [
        '-binarymonitor',
        '-binarymonitoraddress', `${this.host}:${this.port}`,
        '+remotemonitor',      // Text monitor kikapcsolása
        '-autostartprgmode', '1',  // RAM inject mód
    ];
    // NEM adjuk meg a PRG fájlt!
    this.viceProcess = spawn(this.vicePath, args);
}
```

### 2. ViceClient kiegészítések

```typescript
// vice-client.ts

async reset(): Promise<void> {
    // 0xCC - Reset parancs
    const body = Buffer.from([0x00]);  // Soft reset
    await this.sendCommand(CommandType.RESET, body);
}

async autostart(filename: string, run: boolean = true): Promise<void> {
    // 0xDD - Autostart parancs
    const body = Buffer.alloc(3 + filename.length);
    body.writeUInt8(run ? 0x01 : 0x00, 0);  // Run flag
    body.writeUInt16LE(0, 1);                // File index
    Buffer.from(filename).copy(body, 3);     // Filename

    await this.sendCommand(CommandType.AUTOSTART, body);
}
```

### 3. Event kezelés javítása

```typescript
// debug-session.ts

private setupViceEventHandlers(): void {
    this.viceClient.on('stopped', (data: StoppedEventData) => {
        // PC lekérése a regiszterekből
        const registers = await this.viceClient.getRegisters();

        // Source location keresése
        const source = this.sourceMapper.getSourceLocation(registers.pc);

        // DAP StoppedEvent küldése
        this.sendEvent(new StoppedEvent('breakpoint', 1));
    });
}
```

## Hibakeresési tippek

### VICE output figyelése

```bash
# VICE stdout/stderr átirányítása
x64sc -binarymonitor 2>&1 | tee vice.log
```

### Binary protocol debugging

```typescript
// Minden küldött/fogadott üzenet logolása
socket.on('data', (data) => {
    console.log('RECV:', data.toString('hex'));
});

const originalWrite = socket.write.bind(socket);
socket.write = (data) => {
    console.log('SEND:', data.toString('hex'));
    return originalWrite(data);
};
```

### Gyakori hibák

| Hiba | Ok | Megoldás |
|------|-----|----------|
| CMD_FAILURE (0x8f) autostart | VICE már fut/tölt | Reset küldése előtte |
| Breakpoint nem üt be | PC már túlment | Reset + autostart sorrend |
| Timeout | VICE lassú indulás | Retry loop növelése |
| Disconnected | VICE crash/quit | Error handling javítása |

## Források

- [VICE Binary Monitor Protocol](https://vice-emu.sourceforge.io/vice_13.html)
- [VS Code Debug Adapter Protocol](https://microsoft.github.io/debug-adapter-protocol/)
- [VS64 Source Code](https://github.com/rolandshacks/vs64/tree/master/src/debugger)
- [cc65-debugger Source Code](https://github.com/empathicqubit/vscode-cc65-debugger/tree/master/src/dbg)
