# RealMail - description
# E-Mail Client Spezifikation

## Übersicht

Lokaler E-Mail-Client für macOS mit schneller Datenbankanbindung, automatischer Absender-Gruppierung und Bulk-Mail-Erkennung.

## Architektur

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│  IMAP/POP3      │────▶│  Sync-Server │────▶│  SQLite/DuckDB  │
│  Mail-Server    │◀────│              │◀────│  Lokale DB      │
└─────────────────┘     └──────────────┘     └─────────────────┘
                                                      │
                                                      ▼
                                             ┌─────────────────┐
                                             │  Frontend UI    │
                                             │  (Native macOS) │
                                             └─────────────────┘
```

## Komponenten

### 1. Mail-Sync-Service

**Funktion**: Lädt E-Mails von IMAP/POP3 und synchronisiert Änderungen bidirektional.

**Anforderungen**:
- IMAP IDLE für Push-Benachrichtigungen
- POP3 als Fallback
- Vollständige E-Mail-Speicherung (Header, Body, Attachments, Flags)
- Bidirektionale Sync (lokale Änderungen → Server)
- OAuth2 und App-Passwörter

**Technologie**: Python mit `imapclient`, `aiosmtplib`

### 2. Lokale Datenbank

**Anforderungen**:
- Schnelle Volltextsuche
- Effiziente Abfragen nach Absender, Datum, Flags
- Attachment-Speicherung (Dateisystem mit DB-Referenz)
- < 50ms Antwortzeit für typische Abfragen

**Schema**:

```sql
CREATE TABLE accounts (
    id INTEGER PRIMARY KEY,
    email TEXT NOT NULL,
    server_type TEXT CHECK(server_type IN ('imap', 'pop3')),
    host TEXT NOT NULL,
    port INTEGER,
    credentials_ref TEXT
);

CREATE TABLE senders (
    id INTEGER PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    display_name TEXT,
    is_bulk_sender BOOLEAN DEFAULT FALSE,
    bulk_category TEXT
);

CREATE TABLE emails (
    id INTEGER PRIMARY KEY,
    account_id INTEGER REFERENCES accounts(id),
    sender_id INTEGER REFERENCES senders(id),
    message_id TEXT UNIQUE,
    subject TEXT,
    body_text TEXT,
    body_html TEXT,
    received_at TIMESTAMP NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    is_starred BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,
    folder TEXT,
    raw_headers TEXT,
    sync_status TEXT CHECK(sync_status IN ('synced', 'pending', 'conflict'))
);

CREATE TABLE attachments (
    id INTEGER PRIMARY KEY,
    email_id INTEGER REFERENCES emails(id),
    filename TEXT,
    mime_type TEXT,
    size_bytes INTEGER,
    storage_path TEXT
);

CREATE INDEX idx_emails_sender ON emails(sender_id);
CREATE INDEX idx_emails_received ON emails(received_at);
CREATE INDEX idx_emails_folder ON emails(folder);
CREATE VIRTUAL TABLE emails_fts USING fts5(subject, body_text);
```

**Technologie**: SQLite mit FTS5 oder DuckDB

### 3. Bulk-Mail-Erkennung

**Klassifizierung**:
- List-Unsubscribe Header vorhanden
- Precedence: bulk/list Header
- Mehrere Empfänger in To/CC (> 10)
- Bekannte Newsletter-Domains
- Mailing-List Header (List-Id, List-Post)

**Kategorien**:
- Newsletter
- Marketing
- Notifications (GitHub, Linear, etc.)
- Transactional (Rechnungen, Bestätigungen)

### 4. Frontend UI

**Layout** (3-Spalten):

```
┌─────────────┬────────────────────┬─────────────────────────────────────┐
│ MODUS       │ E-MAIL-LISTE       │ E-MAIL-INHALT                       │
├─────────────┼────────────────────┼─────────────────────────────────────┤
│             │                    │                                     │
│ ┌─────────┐ │                    │                                     │
│ │Timeline │ │                    │                                     │
│ └─────────┘ │                    │                                     │
│             │                    │                                     │
│ ┌─────────┐ │                    │                                     │
│ │  Bulk   │ │                    │                                     │
│ └─────────┘ │                    │                                     │
│             │                    │                                     │
│ ┌─────────┐ │                    │                                     │
│ │ Direkt  │ │                    │                                     │
│ └─────────┘ │                    │                                     │
│             │                    │                                     │
└─────────────┴────────────────────┴─────────────────────────────────────┘
```

**Modus 1: Timeline**
Zeigt alle E-Mails chronologisch OHNE Bulk-Mails. Gruppiert nach Zeitabschnitten:

```
┌─────────────┬────────────────────┬─────────────────────────────────────┐
│ MODUS       │ E-MAIL-LISTE       │ E-MAIL-INHALT                       │
├─────────────┼────────────────────┼─────────────────────────────────────┤
│             │ ▼ Today            │                                     │
│ [Timeline]◀ │   Max: Re: Projekt │  Von: Max Müller                    │
│             │   Anna: Frage zu.. │  Betreff: Re: Projekt               │
│  Bulk       │ ▼ Yesterday        │                                     │
│             │   Chef: Meeting    │  Hallo Markus,                      │
│  Direkt     │ ▼ This Week        │                                     │
│             │   ...              │  Lorem ipsum...                     │
│             │ ▼ This Month       │                                     │
│             │ ▼ This Quarter     │                                     │
│             │ ▼ This Year        │                                     │
│             │ ▼ Older            │                                     │
└─────────────┴────────────────────┴─────────────────────────────────────┘
```

**Modus 2: Bulk**
Zeigt nur Bulk-Mails, gruppiert nach Absender:

```
┌─────────────┬────────────────────┬─────────────────────────────────────┐
│ MODUS       │ E-MAIL-LISTE       │ E-MAIL-INHALT                       │
├─────────────┼────────────────────┼─────────────────────────────────────┤
│             │ ▼ Heise (12)       │                                     │
│  Timeline   │   Neue Security..  │  Heise Newsletter                   │
│             │   Linux-Kernel..   │  Betreff: Neue Security-Lücke       │
│ [Bulk]    ◀ │ ▼ GitHub (45)      │                                     │
│             │   PR merged: ..    │  Sehr geehrte Leser,                │
│  Direkt     │   Issue opened:..  │                                     │
│             │ ▼ Linear (8)       │  Lorem ipsum...                     │
│             │   Task assigned..  │                                     │
│             │ ▼ Amazon (3)       │                                     │
│             │   Ihre Bestellung  │                                     │
└─────────────┴────────────────────┴─────────────────────────────────────┘
```

**Modus 3: Direkt**
Zeigt nur direkte E-Mails (nicht Bulk), gruppiert nach Absender:

```
┌─────────────┬────────────────────┬─────────────────────────────────────┐
│ MODUS       │ E-MAIL-LISTE       │ E-MAIL-INHALT                       │
├─────────────┼────────────────────┼─────────────────────────────────────┤
│             │ ▼ Max Müller (5)   │                                     │
│  Timeline   │   Re: Projekt      │  Von: Max Müller                    │
│             │   Frage zu API     │  Betreff: Re: Projekt               │
│  Bulk       │ ▼ Anna Schmidt (3) │                                     │
│             │   Meeting morgen   │  Hi Markus,                         │
│ [Direkt]  ◀ │   Dokumente        │                                     │
│             │ ▼ Chef (2)         │  Hier die Infos...                  │
│             │   Q4 Review        │                                     │
│             │   Budget 2025      │                                     │
└─────────────┴────────────────────┴─────────────────────────────────────┘
```

**Zeitabschnitt-Logik** (nur für Timeline-Modus):
- Today: `received_at >= today 00:00`
- Yesterday: `received_at >= yesterday 00:00 AND < today 00:00`
- This Week: Aktuelle Kalenderwoche (Montag-Start)
- This Month: Aktueller Kalendermonat
- This Quarter: Q1/Q2/Q3/Q4 des aktuellen Jahres
- This Year: Aktuelles Kalenderjahr
- Older: Alles davor

**Keyboard Shortcuts**:
- `j/k`: Nächste/Vorherige E-Mail
- `Enter`: E-Mail öffnen
- `r`: Antworten
- `a`: Allen antworten
- `f`: Weiterleiten
- `d`: Löschen
- `s`: Stern toggle
- `/`: Suche
- `1-7`: Zeitfilter wählen

**Technologie**: Swift/SwiftUI (native macOS) oder Tauri (Rust + Web)

## Sync-Protokoll

### Background-Sync-Service

Der Sync läuft vollständig automatisch im Hintergrund als separater Prozess/Thread.

```
┌─────────────────────────────────────────────────────────────────┐
│                    Background Sync Service                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │ IMAP IDLE    │    │ Polling      │    │ Change       │       │
│  │ Listener     │    │ Fallback     │    │ Watcher      │       │
│  │ (Push)       │    │ (30s)        │    │ (DB → IMAP)  │       │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘       │
│         │                   │                   │                │
│         └───────────────────┼───────────────────┘                │
│                             ▼                                    │
│                    ┌────────────────┐                            │
│                    │  Sync Queue    │                            │
│                    │  (Priority)    │                            │
│                    └────────┬───────┘                            │
│                             ▼                                    │
│                    ┌────────────────┐                            │
│                    │  DB Writer     │                            │
│                    │  (Batch)       │                            │
│                    └────────┬───────┘                            │
│                             ▼                                    │
│                    ┌────────────────┐                            │
│                    │  UI Event Bus  │──────▶ Frontend Update     │
│                    └────────────────┘                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Komponenten**:

1. **IMAP IDLE Listener**: Hält persistente Verbindung, reagiert sofort auf neue Mails
2. **Polling Fallback**: Falls IDLE nicht unterstützt oder Verbindung abbricht (30s Intervall)
3. **Change Watcher**: Überwacht DB auf lokale Änderungen (gelesen, gelöscht, verschoben)
4. **Sync Queue**: Priorisiert Operationen (neue Mails > Flag-Updates > Deletes)
5. **DB Writer**: Batch-Writes für Performance (max 100ms Verzögerung)
6. **UI Event Bus**: Benachrichtigt Frontend über Änderungen

**Lifecycle**:

```python
class BackgroundSyncService:
    async def start(self):
        """Startet beim App-Start automatisch"""
        self.running = True
        await asyncio.gather(
            self._idle_listener(),
            self._polling_fallback(),
            self._change_watcher(),
            self._queue_processor()
        )
    
    async def stop(self):
        """Graceful shutdown bei App-Ende"""
        self.running = False
        await self._flush_pending()
        await self._close_connections()
```

**Automatischer Reconnect**:

- Bei Verbindungsabbruch: Exponential Backoff (1s, 2s, 4s, ... max 5min)
- Bei Auth-Fehler: Token-Refresh, dann Retry
- Bei permanentem Fehler: UI-Benachrichtigung, manueller Retry-Button

### Server → Lokal (automatisch)

1. IMAP IDLE wartet auf EXISTS/EXPUNGE Notifications
2. Bei Notification: FETCH für neue/geänderte UIDs
3. Einfügen in Sync Queue mit Priorität
4. Queue Processor schreibt batch-weise in DB
5. Event Bus triggert UI-Update (neue Mail Badge, Liste aktualisieren)

### Lokale Änderung → Server (automatisch)

1. UI-Aktion ändert DB mit `sync_status = 'pending'`
2. Change Watcher erkennt pending innerhalb 100ms
3. Einfügen in Sync Queue
4. Queue Processor führt IMAP-Befehl aus:
   - Flag ändern: `STORE uid +FLAGS (\Seen)`
   - Löschen: `STORE uid +FLAGS (\Deleted)` + `EXPUNGE`
   - Verschieben: `COPY uid folder` + `STORE +FLAGS (\Deleted)` + `EXPUNGE`
5. Bei Erfolg: `sync_status = 'synced'`
6. Bei Fehler: Retry mit Backoff, nach 3 Fehlern `sync_status = 'conflict'`

### Offline-Handling

```
Online:  ●──────────────────●───────────────●
                            │               │
Offline:                    ●───────────────●
                            │               │
Actions: [read] [delete]    │  [queued]     │ [sync all]
                            │               │
DB:      synced  synced     │  pending      │ synced
```

- Alle Aktionen werden lokal in DB gespeichert
- `sync_status = 'pending'` für offline Änderungen
- Bei Reconnect: Alle pending Änderungen automatisch synchronisieren
- Konfliktauflösung: Server wins (mit UI-Warnung)

## Projektstruktur

```
email-client/
├── backend/
│   ├── pyproject.toml
│   ├── src/
│   │   ├── sync/
│   │   │   ├── imap_client.py
│   │   │   ├── pop3_client.py
│   │   │   └── sync_service.py
│   │   ├── db/
│   │   │   ├── models.py
│   │   │   ├── queries.py
│   │   │   └── migrations/
│   │   ├── classification/
│   │   │   └── bulk_detector.py
│   │   └── api/
│   │       └── server.py
│   └── tests/
├── frontend/
│   ├── Package.swift (oder Cargo.toml für Tauri)
│   └── Sources/
└── README.md
```

## Nicht-funktionale Anforderungen

- **Performance**: UI-Reaktionszeit < 100ms, Suche < 500ms für 100k E-Mails
- **Speicher**: < 500MB RAM bei 100k E-Mails
- **Offline**: Vollständig offline-fähig, Sync bei Verbindung
- **Sicherheit**: Credentials in macOS Keychain, DB optional verschlüsselt

## Meilensteine

1. **M1**: IMAP-Sync + SQLite-Speicherung (2 Wochen)
2. **M2**: Bulk-Erkennung + Absender-Gruppierung (1 Woche)
3. **M3**: Basis-UI mit 3-Spalten-Layout (2 Wochen)
4. **M4**: Bidirektionaler Sync (1 Woche)
5. **M5**: Zeitfilter + Keyboard-Navigation (1 Woche)
6. **M6**: Polishing + Performance-Optimierung (1 Woche)

# RealMail - Technical Specifications Reference

This document provides a comprehensive inventory of all technical specifications, protocols, standards, and RFCs implemented in the RealMail project.

---

## Table of Contents

1. [IMAP Protocol (RFC 3501)](#1-imap-protocol-rfc-3501)
2. [IMAP Extensions](#2-imap-extensions)
3. [Email Format Standards](#3-email-format-standards)
4. [MIME Specifications](#4-mime-specifications)
5. [Transfer Encoding Schemes](#5-transfer-encoding-schemes)
6. [Authentication Methods](#6-authentication-methods)
7. [TLS/SSL Configuration](#7-tlsssl-configuration)
8. [Certificate Pinning](#8-certificate-pinning)
9. [HTML Rendering & Security](#9-html-rendering--security)
10. [Mailing List Standards](#10-mailing-list-standards)
11. [Concurrency Model](#11-concurrency-model)
12. [Error Handling](#12-error-handling)
13. [RFC Reference Table](#13-rfc-reference-table)

---

## 1. IMAP Protocol (RFC 3501)

### 1.1 Core Commands Implemented

| Command | Description | Reference |
|---------|-------------|-----------|
| `CAPABILITY` | Server capability discovery | RFC 3501 §6.1.1 |
| `LOGIN` | Basic password authentication | RFC 3501 §6.2.3 |
| `AUTHENTICATE` | SASL authentication mechanism | RFC 3501 §6.2.2 |
| `SELECT` | Folder selection | RFC 3501 §6.3.1 |
| `EXAMINE` | Read-only folder selection | RFC 3501 §6.3.2 |
| `LIST` | List available mailboxes | RFC 3501 §6.3.8 |
| `STATUS` | Folder status query | RFC 3501 §6.3.10 |
| `UID FETCH` | Message retrieval by UID | RFC 3501 §6.4.8 |
| `UID SEARCH` | Server-side message search | RFC 3501 §6.4.4 |
| `UID STORE` | Flag modification | RFC 3501 §6.4.6 |
| `UID COPY` | Copy messages | RFC 3501 §6.4.7 |
| `EXPUNGE` | Delete marked messages | RFC 3501 §6.4.3 |
| `NOOP` | Health check / keepalive | RFC 3501 §6.1.2 |
| `LOGOUT` | Connection termination | RFC 3501 §6.1.3 |
| `IDLE` | Push notifications | RFC 2177 |

### 1.2 FETCH Data Items

```
FETCH (
    UID              - Unique message identifier
    ENVELOPE         - Message metadata/headers (RFC 3501 §7.4.2)
    BODYSTRUCTURE    - MIME structure (RFC 3501 §7.4.2)
    BODY[section]    - Message body parts
    BODY[TEXT]       - Full message text
    BODY[HEADER]     - Message headers
    RFC822.SIZE      - Message size in octets
    FLAGS            - Message flags
    INTERNALDATE     - Server receipt date
)
```

### 1.3 Body Part Specifiers

| Specifier | Description |
|-----------|-------------|
| `BODY[TEXT]` | Full RFC 822 text portion |
| `BODY[HEADER]` | All headers |
| `BODY[1]` | First MIME part (usually text/plain) |
| `BODY[2]` | Second MIME part (usually text/html) |
| `BODY[1.1]` | Nested part (first part of first part) |
| `BODY[1.2]` | Second nested part |

### 1.4 Message Flags

| Flag | Description | Type |
|------|-------------|------|
| `\Seen` | Message has been read | System |
| `\Answered` | Message has been replied to | System |
| `\Flagged` | Message is flagged/starred | System |
| `\Deleted` | Message marked for deletion | System |
| `\Draft` | Message is a draft | System |
| `\Recent` | Message is recent (read-only) | System |

### 1.5 Mailbox Flags

| Flag | Description | Reference |
|------|-------------|-----------|
| `\Noselect` | Mailbox cannot be selected | RFC 3501 |
| `\HasChildren` | Mailbox has child mailboxes | RFC 3501 |
| `\HasNoChildren` | Mailbox has no children | RFC 3501 |
| `\Marked` | Mailbox is marked | RFC 3501 |
| `\Unmarked` | Mailbox is not marked | RFC 3501 |

### 1.6 Special-Use Mailbox Flags (RFC 6154)

| Flag | Description |
|------|-------------|
| `\Drafts` | Drafts folder |
| `\Sent` | Sent messages |
| `\Trash` | Trash/Deleted items |
| `\Junk` | Spam/Junk mail |
| `\Archive` | Archive folder |
| `\All` | All mail (virtual) |
| `\Flagged` | Flagged messages (virtual) |
| `\Important` | Important messages |

### 1.7 STATUS Response Items

```
STATUS mailbox (
    MESSAGES      - Total message count
    RECENT        - Recent message count
    UNSEEN        - Unread message count
    UIDNEXT       - Next expected UID
    UIDVALIDITY   - UID validity token
    HIGHESTMODSEQ - Highest MODSEQ (RFC 4551)
)
```

---

## 2. IMAP Extensions

### 2.1 Supported Capabilities

| Capability | RFC | Description | Implementation |
|------------|-----|-------------|----------------|
| `IMAP4rev1` | 3501 | Base protocol | Full |
| `IDLE` | 2177 | Push notifications | Full |
| `CONDSTORE` | 4551 | Conditional store | Partial |
| `QRESYNC` | 5162 | Quick resync | Detection only |
| `UIDPLUS` | 4315 | UID extensions | Detection only |
| `MOVE` | 6851 | Message move | Detection only |
| `NAMESPACE` | 2342 | Namespace access | Detection only |
| `LITERAL+` | 2088 | Non-sync literals | Detection only |
| `COMPRESS=DEFLATE` | 4978 | Compression | Detection only |
| `ID` | 2971 | Server identification | Detection only |
| `ENABLE` | 5161 | Feature enabling | Detection only |
| `UNSELECT` | 3691 | Unselect mailbox | Detection only |
| `SORT` | 5256 | Server-side sort | Detection only |
| `THREAD=REFERENCES` | 5256 | Threading | Detection only |

### 2.2 IMAP IDLE (RFC 2177)

**Protocol Flow:**
```
C: A001 IDLE
S: + idling
... server sends unsolicited responses ...
S: * 3 EXISTS
S: * 2 RECENT
C: DONE
S: A001 OK IDLE terminated
```

**Configuration:**
- Timeout: 25 minutes (RFC recommends ≤29 minutes)
- Restart: Automatic after timeout or server response
- Events monitored: `EXISTS`, `RECENT`, `EXPUNGE`, `FETCH`

**Supported Events:**
| Event | Description |
|-------|-------------|
| `EXISTS` | New message arrived |
| `RECENT` | Recent count changed |
| `EXPUNGE` | Message deleted |
| `FETCH` | Message flags changed |

### 2.3 CONDSTORE (RFC 4551)

**MODSEQ Support:**
```
C: A001 UID SEARCH MODSEQ 12345
S: * SEARCH 1 2 3 (MODSEQ 12350)
S: A001 OK Search completed
```

Used for incremental synchronization - only fetching messages modified since last sync.

---

## 3. Email Format Standards

### 3.1 Internet Message Format (RFC 5322)

**Message Structure:**
```
Headers (RFC 5322 §2.2)
    Date: <date-time>
    From: <mailbox-list>
    To: <address-list>
    Cc: <address-list>
    Subject: <unstructured>
    Message-ID: <msg-id>
    In-Reply-To: <msg-id>
    References: <msg-id-list>
<CRLF>
Body
```

**ENVELOPE Structure (RFC 3501 §7.4.2):**
```
(
    date            ; RFC 5322 Date
    subject         ; Subject (may be encoded per RFC 2047)
    from            ; From address list
    sender          ; Sender address list
    reply-to        ; Reply-To address list
    to              ; To address list
    cc              ; Cc address list
    bcc             ; Bcc address list
    in-reply-to     ; In-Reply-To message ID
    message-id      ; Message-ID
)
```

### 3.2 Email Address Format (RFC 5321/5322)

**Validation Pattern:**
```regex
^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$
```

**Constraints:**
- Maximum total length: 254 characters (RFC 5321)
- Local part maximum: 64 characters
- Domain part maximum: 255 characters

**Display Formats:**
```
"Display Name" <email@domain.com>   ; Full format
email@domain.com                     ; Simple format
<email@domain.com>                   ; Angle bracket format
```

### 3.3 Date/Time Formats

**IMAP INTERNALDATE:**
```
"DD-Mon-YYYY HH:MM:SS +ZZZZ"
Example: "25-Dec-2024 14:30:00 +0100"
```

**RFC 5322 Date:**
```
day-of-week, DD Mon YYYY HH:MM:SS zone
Example: "Wed, 25 Dec 2024 14:30:00 +0100"
```

---

## 4. MIME Specifications

### 4.1 Content-Type (RFC 2045)

**Format:**
```
Content-Type: type/subtype; parameter=value

Examples:
Content-Type: text/plain; charset=UTF-8
Content-Type: text/html; charset="ISO-8859-1"
Content-Type: multipart/alternative; boundary="----=_Part_123"
Content-Type: application/pdf; name="document.pdf"
```

### 4.2 BODYSTRUCTURE Parsing (RFC 3501 §7.4.2)

**Single Part:**
```
(
    "TEXT"              ; MIME type
    "PLAIN"             ; MIME subtype
    ("CHARSET" "UTF-8") ; Parameters (NIL if none)
    NIL                 ; Content-ID
    NIL                 ; Content-Description
    "7BIT"              ; Content-Transfer-Encoding
    1234                ; Size in octets
    56                  ; Lines (text types only)
)
```

**Multipart:**
```
(
    (body-part-1)
    (body-part-2)
    "ALTERNATIVE"       ; Multipart subtype
)
```

### 4.3 Multipart Types (RFC 2046)

| Type | Description | Usage |
|------|-------------|-------|
| `multipart/mixed` | Unrelated parts | Attachments |
| `multipart/alternative` | Same content, different formats | HTML + Plain text |
| `multipart/related` | Parts with references | HTML with inline images |
| `multipart/digest` | Collection of messages | Message digest |
| `multipart/signed` | Signed content | S/MIME, PGP |

### 4.4 Common MIME Types

| Type | Subtype | Description |
|------|---------|-------------|
| `text` | `plain` | Plain text |
| `text` | `html` | HTML content |
| `image` | `jpeg`, `png`, `gif` | Images |
| `application` | `pdf` | PDF documents |
| `application` | `octet-stream` | Binary data |

---

## 5. Transfer Encoding Schemes

### 5.1 Content-Transfer-Encoding (RFC 2045)

| Encoding | Description | Use Case |
|----------|-------------|----------|
| `7BIT` | 7-bit ASCII only | Simple text |
| `8BIT` | 8-bit data | Extended ASCII |
| `BINARY` | Raw binary | Binary attachments |
| `QUOTED-PRINTABLE` | Printable encoding | Text with special chars |
| `BASE64` | Base64 encoding | Binary data, attachments |

### 5.2 BASE64 Encoding (RFC 2045 §6.8)

**Alphabet:**
```
ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/
Padding: =
```

**Decoding Process:**
1. Remove line breaks (CRLF)
2. Remove whitespace
3. Decode 4 characters → 3 bytes
4. Handle padding (`=`, `==`)

### 5.3 QUOTED-PRINTABLE Encoding (RFC 2045 §6.7)

**Rules:**
- Printable ASCII (33-126, except `=`) → literal
- Other bytes → `=XX` (hex)
- Space at line end → `=20`
- Soft line break → `=` at end of line
- Maximum line length: 76 characters

**Example:**
```
Input:  "Grüße"
Output: "Gr=C3=BC=C3=9Fe"
```

### 5.4 MIME Encoded-Word (RFC 2047)

**Format:**
```
=?charset?encoding?encoded_text?=

Examples:
=?UTF-8?B?R3LDvMOfZQ==?=        ; Base64 encoded
=?UTF-8?Q?Gr=C3=BC=C3=9Fe?=    ; Quoted-Printable encoded
```

**Supported Charsets:**
- UTF-8 (preferred)
- ISO-8859-1 (Latin-1)
- ISO-8859-2 (Latin-2)
- Windows-1252 (CP1252)
- US-ASCII

---

## 6. Authentication Methods

### 6.1 LOGIN Command (RFC 3501 §6.2.3)

```
C: A001 LOGIN "username" "password"
S: A001 OK LOGIN completed
```

**Security Notes:**
- Should only be used over TLS
- Password sent in cleartext (within TLS tunnel)
- Deprecated in favor of SASL mechanisms

### 6.2 OAuth 2.0 / XOAUTH2 (RFC 6750)

**SASL XOAUTH2 Mechanism:**
```
C: A001 AUTHENTICATE XOAUTH2 <base64_token>
S: A001 OK AUTHENTICATE completed
```

**Token Format (before Base64):**
```
user=<email>\x01auth=Bearer <access_token>\x01\x01
```

**Supported Providers:**
| Provider | OAuth Endpoint | Scopes |
|----------|---------------|--------|
| Google | accounts.google.com | `https://mail.google.com/` |
| Microsoft | login.microsoftonline.com | `https://outlook.office.com/IMAP.AccessAsUser.All` |

### 6.3 Credential Storage (macOS Keychain)

**Keychain Configuration:**
```swift
kSecClass: kSecClassGenericPassword
kSecAttrService: "com.realmail.account.<accountId>"
kSecAttrAccount: <email>
kSecAttrAccessible: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
```

**Security Features:**
- Hardware encryption (Secure Enclave on T2/M1/M2)
- Biometric authentication support
- Memory wiping after use (`memset`)
- No credential logging

---

## 7. TLS/SSL Configuration

### 7.1 Network Framework Configuration

**Minimum TLS Version:** TLS 1.2

```swift
sec_protocol_options_set_min_tls_protocol_version(
    options,
    .TLSv12
)
```

### 7.2 Connection Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 993 | IMAPS | IMAP over TLS (implicit) |
| 143 | IMAP | Plain IMAP (not supported) |

**Note:** STARTTLS on port 143 is intentionally not supported for security reasons.

### 7.3 Cipher Suites

Relies on system defaults with TLS 1.2+ requirement:
- TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
- TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
- TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
- TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256

---

## 8. Certificate Pinning

### 8.1 Public Key Pinning (SPKI)

**Hash Algorithm:** SHA-256 (Base64 encoded)

**Configuration Structure:**
```swift
struct PinConfiguration {
    let pins: [String]           // Base64 SHA-256 hashes
    let includeSubdomains: Bool
    let validationMode: ValidationMode
}

enum ValidationMode {
    case strict        // Reject if no pin match
    case allowFallback // Fall back to system validation
}
```

### 8.2 Pin Generation

```bash
# Extract public key and generate pin
openssl s_client -connect imap.gmail.com:993 | \
openssl x509 -pubkey -noout | \
openssl pkey -pubin -outform der | \
openssl dgst -sha256 -binary | \
openssl enc -base64
```

### 8.3 Recommended Pinning Strategy

1. Pin leaf certificate public key
2. Pin intermediate CA public key (backup)
3. Update pins before certificate rotation

---

## 9. HTML Rendering & Security

### 9.1 Content Security Policy (CSP)

```
Content-Security-Policy:
    default-src 'none';
    img-src * data:;
    style-src 'unsafe-inline';
    font-src *;
```

| Directive | Value | Purpose |
|-----------|-------|---------|
| `default-src` | `'none'` | Block all by default |
| `img-src` | `* data:` | Allow images from any source |
| `style-src` | `'unsafe-inline'` | Allow inline styles |
| `font-src` | `*` | Allow fonts from any source |
| `script-src` | (blocked) | No JavaScript execution |

### 9.2 HTML Sanitization

**Removed Tags:**
```
<script>, <style>, <iframe>, <object>, <embed>,
<form>, <base>, <link>, <meta>, <svg>, <applet>,
<frameset>, <frame>
```

**Removed Attributes:**
```
onclick, onload, onerror, onmouseover, onmouseout,
onfocus, onblur, onchange, onsubmit, onkeydown,
onkeyup, onkeypress, style (when containing expressions)
```

**Blocked URL Schemes:**
```
javascript:, vbscript:, data:, file:
```

### 9.3 Link Classification

| Type | Pattern | Action |
|------|---------|--------|
| `web` | `http://`, `https://` | Open in browser |
| `email` | `mailto:` | Compose email |
| `phone` | `tel:` | Open phone app |
| `tracking` | Known tracking domains | Warning indicator |

**Tracking Domain Patterns:**
```
click., track., trk., email., redirect.,
mailtrack., mailchimp., sendgrid., mailgun.
```

---

## 10. Mailing List Standards

### 10.1 List-Id Header (RFC 2919)

**Format:**
```
List-Id: <list-name.example.com>
List-Id: List Name <list-name.example.com>
```

**Usage:** Primary identifier for mailing list categorization.

### 10.2 List-Unsubscribe (RFC 2369)

**Format:**
```
List-Unsubscribe: <mailto:unsubscribe@list.example.com>
List-Unsubscribe: <mailto:...>, <https://example.com/unsubscribe>
```

**Supported Methods:**
- `mailto:` - Email-based unsubscribe
- `http:`/`https:` - Web-based unsubscribe

### 10.3 One-Click Unsubscribe (RFC 8058)

**Headers:**
```
List-Unsubscribe: <https://example.com/unsubscribe>
List-Unsubscribe-Post: List-Unsubscribe=One-Click
```

**Behavior:** Single HTTP POST request triggers unsubscribe.

---

## 11. Concurrency Model

### 11.1 Swift Actors

**Actor-based Components:**
```swift
actor IMAPSession { }      // Connection management
actor IMAPImpl { }         // Protocol implementation
actor IMAPConnection { }   // Raw TCP handling
actor IDLEMonitor { }      // IDLE state machine
actor ResponseAssembler { } // Response buffering
```

**Thread Safety Guarantees:**
- Serialized access to mutable state
- No data races by design
- Async/await for non-blocking operations

### 11.2 Circuit Breaker Pattern

**States:**
```
closed ──[failures >= threshold]──► open
   ▲                                  │
   │                                  │
   └──[success]── halfOpen ◄──[timeout]──┘
```

**Configuration:**
| Parameter | Value |
|-----------|-------|
| Failure Threshold | 5 |
| Recovery Timeout | 60 seconds |
| Failure Window | 300 seconds |
| Health Check Interval | 30 seconds |

---

## 12. Error Handling

### 12.1 IMAP Error Categories

**Connection Errors:**
| Error | Description | Recoverable |
|-------|-------------|-------------|
| `connectionFailed` | TCP connection failed | Yes |
| `connectionTimeout` | Connection timed out | Yes |
| `sslError` | TLS handshake failed | No |
| `alreadyConnected` | Already connected | No |

**Authentication Errors:**
| Error | Description | Recoverable |
|-------|-------------|-------------|
| `authenticationFailed` | Login rejected | No |
| `invalidCredentials` | Bad username/password | No |
| `oauth2TokenExpired` | Token needs refresh | Yes |
| `oauth2RefreshFailed` | Token refresh failed | No |

**Protocol Errors:**
| Error | Description | Recoverable |
|-------|-------------|-------------|
| `invalidGreeting` | Bad server greeting | No |
| `commandFailed` | Command rejected | Depends |
| `unexpectedResponse` | Parsing failed | No |
| `parseError` | Malformed response | No |

### 12.2 Retry Strategy

**Recoverable Operations:**
```swift
let retryableErrors: Set<IMAPError> = [
    .connectionFailed,
    .connectionTimeout,
    .idleInterrupted,
    .oauth2TokenExpired
]
```

**Retry Delays:**
| Operation | Delay |
|-----------|-------|
| Connection | 2.0 seconds |
| IDLE restart | 1.0 seconds |
| OAuth refresh | Immediate |

---

## 13. RFC Reference Table

| RFC | Title | Status |
|-----|-------|--------|
| **RFC 2045** | MIME Part One: Format of Internet Message Bodies | Implemented |
| **RFC 2046** | MIME Part Two: Media Types | Implemented |
| **RFC 2047** | MIME Part Three: Message Header Extensions | Implemented |
| **RFC 2088** | IMAP4 non-synchronizing literals | Detected |
| **RFC 2177** | IMAP4 IDLE command | Implemented |
| **RFC 2342** | IMAP4 Namespace | Detected |
| **RFC 2369** | URLs as Meta-Syntax for List Commands | Implemented |
| **RFC 2919** | List-Id: A Structured Field for Mailing Lists | Implemented |
| **RFC 2971** | IMAP4 ID extension | Detected |
| **RFC 3501** | IMAP VERSION 4rev1 | Implemented |
| **RFC 3691** | IMAP UNSELECT command | Detected |
| **RFC 4315** | IMAP UIDPLUS extension | Detected |
| **RFC 4551** | IMAP CONDSTORE Extension | Partial |
| **RFC 4978** | The IMAP COMPRESS Extension | Detected |
| **RFC 5161** | The IMAP ENABLE Extension | Detected |
| **RFC 5162** | IMAP QRESYNC Extension | Detected |
| **RFC 5256** | IMAP SORT and THREAD Extensions | Detected |
| **RFC 5321** | Simple Mail Transfer Protocol | Referenced |
| **RFC 5322** | Internet Message Format | Implemented |
| **RFC 6154** | IMAP LIST Special-Use Mailboxes | Implemented |
| **RFC 6750** | OAuth 2.0 Bearer Token Usage | Implemented |
| **RFC 6851** | IMAP MOVE Extension | Detected |
| **RFC 8058** | Signaling One-Click Functionality | Implemented |

---

## Appendix A: IMAP Response Parsing

### A.1 Response Types

**Untagged Responses:**
```
* OK [CAPABILITY ...] Server ready
* 5 EXISTS
* 2 RECENT
* 3 FETCH (...)
* SEARCH 1 2 3
* LIST (\HasChildren) "/" "INBOX"
```

**Tagged Responses:**
```
A001 OK Command completed
A002 NO Command failed
A003 BAD Invalid command
```

### A.2 Continuation Requests

```
+ Ready for additional command text
```

Used for:
- IDLE continuation
- Literal data upload
- AUTHENTICATE challenges

---

## Appendix B: Security Guidelines

### B.1 Credential Handling

1. **Never log credentials** - No passwords in debug output
2. **Clear memory** - Use `memset` after authentication
3. **Keychain storage** - Use highest protection level
4. **No plaintext** - Always encrypt at rest

### B.2 Network Security

1. **TLS 1.2+** - Minimum TLS version enforced
2. **Certificate pinning** - Optional but recommended
3. **No fallback** - No downgrade to unencrypted

### B.3 Content Security

1. **Sanitize HTML** - Remove dangerous elements
2. **CSP headers** - Restrict content sources
3. **Disable JavaScript** - No script execution in emails
4. **Validate URLs** - Check scheme before opening

---

*Document generated for RealMail project*
*Last updated: 2024*
