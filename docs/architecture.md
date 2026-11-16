# Architecture

```mermaid
flowchart LR
    CPU <-->|CPU request and response| CTRL[Cache controller]
    CTRL -->|latched address| DEC[Address decoder]
    DEC -->|set and tag| TAG[Tag array and comparators]
    DEC -->|set| DATA[Data array]
    DEC -->|set| LRU[Per-set LRU]
    TAG -->|hits and dirty bits| CTRL
    TAG -->|valid bits| LRU
    DATA -->|hit and victim data| CTRL
    LRU -->|victim way| CTRL
    CTRL -->|fill or store| TAG
    CTRL -->|fill or store| DATA
    CTRL -->|touch on hit or fill| LRU
    CTRL <-->|refill and write-back| MEM[Behavioral main memory]
```

```mermaid
stateDiagram-v2
    [*] --> IDLE
    IDLE --> TAG_COMPARE: accept CPU request
    TAG_COMPARE --> DONE: hit or alignment error
    TAG_COMPARE --> WRITEBACK: miss with dirty victim
    TAG_COMPARE --> REFILL: miss with clean or invalid victim
    WRITEBACK --> REFILL: memory write completes
    REFILL --> DONE: memory read completes and line is installed
    DONE --> IDLE: response sampled
```

The decoder splits the byte address into tag [31:6], set [5:2], and offset [1:0].
Victim priority is invalid way 0, invalid way 1, then the set's LRU bit.
After accessing way w, the bit records 1 - w.
