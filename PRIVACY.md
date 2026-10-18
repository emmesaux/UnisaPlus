# Informativa sulla Privacy di Unisa Plus

**Ultimo aggiornamento:** 18 Ottobre 2026  
**Applicazione:** Unisa Plus (Android & iOS)  
**Sviluppatore:** Progetto Open Source Indipendente  
**Repository:** [https://github.com/emmesaux/UnisaPlus](https://github.com/emmesaux/UnisaPlus)

---

### 1. Panoramica Generale
Unisa Plus è un'applicazione mobile open source, non ufficiale e indipendente, progettata per facilitare la vita accademica degli studenti dell'Università degli Studi di Salerno (UNISA). La tutela della tua privacy è una priorità assoluta: l'applicazione **non raccoglie, non vende e non condivide alcun dato personale con server di terze parti o sviluppatori terzi**.

---

### 2. Dati Trattati e Finalità

#### A. Dati di Autenticazione e Profilo Studente (Esse3 / CINECA)
- **Cosa viene trattato:** Matricola, nome, cognome, corso di laurea, esami, voti, tasse e credenziali di accesso (memorizzate tramite token o chiavi protette).
- **Come vengono trattati:** Le credenziali e le informazioni accademiche comunicano **esclusivamente e direttamente in formato cifrato (HTTPS/TLS)** tra il tuo dispositivo e i server ufficiali di Ateneo (CINECA Esse3). Nessun dato transita mai su server proprietari o intermedi.
- **Memorizzazione locale:** Le credenziali di sessione vengono salvate unicamente nella memoria cifrata del tuo dispositivo (Keychain su iOS, EncryptedSharedPreferences / Keystore su Android).

#### B. Dati di Presenza e Rilevazione Aule (EasyBadge / CINECA)
- **Cosa viene trattato:** Codice presenza generato tramite scansione del codice QR per la frequenza delle lezioni.
- **Come vengono trattati:** L'app invia la timbratura direttamente agli endpoint dell'ateneo preposti alla verifica delle presenze.

#### C. Dati Saldo e Borsellino Mensa (ADISURC)
- **Cosa viene trattato:** Numero tessera mensa e saldo pasti.
- **Come vengono trattati:** La consultazione avviene connettendosi unicamente agli endpoint del portale ufficiale ADISURC Campania.

#### D. Fotocamera
- L'accesso alla fotocamera viene richiesto **esclusivamente** per la scansione istantanea dei codici QR delle lezioni ai fini della registrazione della presenza in aula. Nessun'immagine o video viene registrato o salvato.

---

### 3. Tracciamento, Cookie e Annunci Pubblicitari
- **Nessuna pubblicità:** L'applicazione è completamente priva di annunci pubblicitari (Google AdMob, Unity Ads, ecc.).
- **Nessun tracker o telemetria di terze parti:** Non sono integrati SDK di tracciamento commerciale, profilazione, Facebook SDK o strumenti di monitoraggio comportamentale.

---

### 4. Conservazione e Cancellazione dell'Account e dei Dati (Account & Data Deletion)
Unisa Plus non gestisce server propri né crea account proprietari: l'autenticazione è delegata ai servizi istituzionali dell'Ateneo.

Per eliminare tutti i dati e le sessioni associate a **Unisa Plus**:
1. **Eliminazione immediata in-app:**
   - Apri l'app **Unisa Plus**
   - Vai nelle Impostazioni / Profilo
   - Tocca **"Logout"** o **"Cancella dati"**
   - Tutti i token di sessione, la matricola e i dati in cache vengono cancellati istantaneamente e definitivamente dal dispositivo (0 giorni di conservazione).
2. **Richiesta di cancellazione via web / supporto:**
   - Poiché non archiviamo dati su server cloud esterni di nostra proprietà, cancellando i dati in locale o disinstallando l'applicazione nessun dato rimane memorizzato.
   - Per qualsiasi richiesta formale di verifica o assistenza sulla rimozione dei dati locali/supporto, puoi aprire una richiesta sul repository ufficiale GitHub:  
     👉 [https://github.com/emmesaux/UnisaPlus/issues](https://github.com/emmesaux/UnisaPlus/issues) o contattare lo sviluppatore all'indirizzo email indicato nella scheda dello Store.
   - **Tipi di dati eliminati:** Credenziali cifrate in locale, numero di matricola, corsi e voti salvati in cache.
   - **Dati conservati:** Nessuno.

---

### 5. Natura Indipendente (Disclaimer)
Unisa Plus è un progetto open source indipendente creato dalla community per gli studenti e **non è un'applicazione governativa né affiliata o sponsorizzata ufficialmente dall'Università degli Studi di Salerno o da ADISURC**. Tutti i marchi registrati appartengono ai rispettivi proprietari.

---

### 6. Contatti
Per domande, segnalazioni o chiarimenti relativi a questa Informativa sulla Privacy, puoi aprire un'issue o contattare i mantainer tramite il repository ufficiale:  
👉 [https://github.com/emmesaux/UnisaPlus](https://github.com/emmesaux/UnisaPlus)

