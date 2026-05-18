# Auto-Derdacha — UML Diagrams (PlantUML)

Three diagrams derived from `architecture.md`:

1. **Class diagram** — domain entities, repositories, APIs, controllers.
2. **Use-case diagram** — actor goals.
3. **Sequence diagrams** — (a) record → transcribe → summarize, (b) schedule meeting + reminder, (c) replay meeting from a folder.

---

## 1. Class diagram

```plantuml
@startuml AutoDerdacha_Class
skinparam classAttributeIconSize 0
skinparam shadowing false
skinparam roundCorner 12
skinparam classBackgroundColor #F5F3FF
skinparam classBorderColor #7C3AED
skinparam stereotypeCBackgroundColor #06B6D4
hide circle

' ===== DOMAIN ENTITIES =====
package "domain.entities" <<Frame>> #EDE9FE {

  enum Category {
    Work
    School
    Family
    Personal
    Custom
  }

  class Folder {
    + id : String
    + name : String
    + category : Category
    + colorHex : String
    + iconKey : String
    + createdAt : DateTime
  }

  class Meeting {
    + id : String
    + folderId : String?
    + title : String
    + audioPath : String
    + transcript : String
    + summaryMd : String
    + durationMs : int
    + language : String
    + model : String
    + createdAt : DateTime
  }

  class SummarySection {
    + heading : String
    + bodyMd : String
  }

  class CalendarEvent {
    + id : String
    + title : String
    + folderId : String?
    + startAt : DateTime
    + endAt : DateTime
    + reminderAt : DateTime?
    + meetingId : String?
  }

  Folder "1" o-- "*" Meeting : contains >
  Meeting "1" o-- "*" SummarySection : structured into >
  CalendarEvent "0..1" --> "0..1" Meeting : realized by >
  Folder "0..1" <-- "*" CalendarEvent : scheduled in >
}

' ===== USE CASES =====
package "domain.usecases" <<Frame>> #DBEAFE {
  class StartRecording
  class StopAndProcess
  class AssignMeetingToFolder
  class ScheduleMeeting
  class LoadHistory
}

' ===== DATA LAYER =====
package "data.repositories" <<Frame>> #FEF3C7 {
  interface MeetingRepository {
    + process(file, folderId?) : Meeting
    + rename(id, title) : void
    + moveToFolder(id, folderId) : void
    + delete(id) : void
    + reSummarize(id) : Meeting
  }
  interface FolderRepository {
    + create(folder) : Folder
    + update(folder) : Folder
    + delete(id, strategy) : void
    + list() : List<Folder>
  }
  interface CalendarRepository {
    + scheduleEvent(event) : CalendarEvent
    + eventsForRange(from, to) : List<CalendarEvent>
    + linkMeeting(eventId, meetingId) : void
  }
}

package "data.remote" <<Frame>> #FCE7F3 {
  class GroqClient {
    - dio : Dio
    - apiKey : String
    - baseUrl : String
  }
  class TranscriptionApi {
    + transcribe(file, language?) : String
  }
  class SummaryApi {
    + summarize(transcript) : String
  }
  TranscriptionApi --> GroqClient
  SummaryApi --> GroqClient
}

package "data.audio" <<Frame>> #DCFCE7 {
  class AudioRecorder {
    + start() : void
    + stop() : File
    + pause() : void
    + resume() : void
    + isRecording : bool
  }
  class AudioPlayer {
    + load(path) : void
    + play() : void
    + pause() : void
    + seek(pos) : void
    + setSpeed(rate) : void
  }
}

package "data.local" <<Frame>> #E0F2FE {
  class AppDatabase
  class MeetingDao
  class FolderDao
  class EventDao
  AppDatabase *-- MeetingDao
  AppDatabase *-- FolderDao
  AppDatabase *-- EventDao
}

' ===== PRESENTATION =====
package "presentation.state" <<Frame>> #FFE4E6 {
  class MeetingController
  class FolderController
  class CalendarController
  class PlayerController
}

' ===== SERVICES =====
package "services" <<Frame>> #F1F5F9 {
  class NotificationService {
    + schedule(eventId, at, payload) : void
    + cancel(eventId) : void
  }
}

' ===== WIRING =====
MeetingRepository ..> AudioRecorder
MeetingRepository ..> TranscriptionApi
MeetingRepository ..> SummaryApi
MeetingRepository ..> MeetingDao
FolderRepository ..> FolderDao
CalendarRepository ..> EventDao
CalendarRepository ..> NotificationService

StartRecording ..> MeetingRepository
StopAndProcess ..> MeetingRepository
AssignMeetingToFolder ..> MeetingRepository
ScheduleMeeting ..> CalendarRepository
LoadHistory ..> MeetingRepository

MeetingController ..> StartRecording
MeetingController ..> StopAndProcess
MeetingController ..> LoadHistory
FolderController ..> FolderRepository
CalendarController ..> ScheduleMeeting
CalendarController ..> CalendarRepository
PlayerController ..> AudioPlayer

@enduml
```

---

## 2. Use-case diagram

```plantuml
@startuml AutoDerdacha_UseCases
left to right direction
skinparam shadowing false
skinparam roundCorner 12
skinparam actorStyle awesome
skinparam usecaseBackgroundColor #F5F3FF
skinparam usecaseBorderColor #7C3AED

actor "User" as U
actor "Groq Cloud" as G <<external>>
actor "OS Notifications" as N <<external>>

rectangle "Auto-Derdacha" {
  usecase "Record a meeting" as UC_Record
  usecase "Stop & process recording" as UC_Stop
  usecase "Transcribe audio" as UC_Trans
  usecase "Summarize transcript" as UC_Sum
  usecase "Re-summarize meeting" as UC_ReSum
  usecase "View meeting details" as UC_View
  usecase "Replay meeting audio" as UC_Replay
  usecase "Export / share summary" as UC_Export

  usecase "Create folder" as UC_NewFolder
  usecase "Assign meeting to folder" as UC_Assign
  usecase "Browse folders" as UC_Browse
  usecase "Pick category & color" as UC_Cat

  usecase "Open calendar" as UC_Cal
  usecase "Schedule a meeting" as UC_Sched
  usecase "Receive reminder" as UC_Remind

  usecase "Toggle dark / light theme" as UC_Theme
  usecase "Grant mic permission" as UC_Perm
}

U --> UC_Record
U --> UC_Stop
U --> UC_View
U --> UC_Replay
U --> UC_Export
U --> UC_ReSum
U --> UC_NewFolder
U --> UC_Assign
U --> UC_Browse
U --> UC_Cal
U --> UC_Sched
U --> UC_Theme

UC_Stop ..> UC_Trans : <<include>>
UC_Trans ..> UC_Sum  : <<include>>
UC_ReSum ..> UC_Sum  : <<include>>
UC_Record ..> UC_Perm : <<include>>
UC_NewFolder ..> UC_Cat : <<include>>
UC_Sched ..> UC_Remind : <<extend>>

UC_Trans --> G
UC_Sum   --> G
UC_Remind --> N
UC_Remind --> U

@enduml
```

---

## 3a. Sequence — Record → Transcribe → Summarize

```plantuml
@startuml AutoDerdacha_Seq_Record
skinparam shadowing false
skinparam roundCorner 10
skinparam sequenceArrowThickness 1.4
skinparam ParticipantBackgroundColor #F5F3FF
skinparam ParticipantBorderColor #7C3AED
skinparam ActorBorderColor #7C3AED

actor User
participant "RecordPage\n(UI)" as UI
participant "MeetingController" as MC
participant "AudioRecorder\n(record pkg)" as AR
participant "MeetingRepository" as MR
participant "TranscriptionApi" as TA
participant "SummaryApi" as SA
participant "Groq Cloud" as G
database "Drift DB" as DB

User -> UI : tap Record
UI -> MC : startRecording()
MC -> AR : start()
AR --> MC : recording...
MC --> UI : state = recording (pulse + waveform)

User -> UI : tap Stop
UI -> MC : stopAndProcess(folderId)
MC -> AR : stop()
AR --> MC : audioFile (.m4a)

MC -> MR : process(audioFile, folderId)
activate MR
MR -> TA : transcribe(audioFile)
TA -> G : POST /audio/transcriptions
G --> TA : transcript text
TA --> MR : transcript

MR -> SA : summarize(transcript)
SA -> G : POST /chat/completions
G --> SA : markdown summary
SA --> MR : summaryMd

MR -> DB : insert Meeting(folderId, paths, transcript, summary)
DB --> MR : meetingId
MR --> MC : Meeting
deactivate MR

MC --> UI : navigate -> MeetingDetailPage(meetingId)
UI --> User : show summary + audio player

== Error path ==
G -[#EF4444]-> TA : 5xx / timeout
TA -[#EF4444]-> MR : Failure
MR -[#EF4444]-> MC : Failure
MC -[#EF4444]-> UI : show retry banner (file kept)
@enduml
```

---

## 3b. Sequence — Schedule a meeting + reminder

```plantuml
@startuml AutoDerdacha_Seq_Schedule
skinparam shadowing false
skinparam roundCorner 10
skinparam ParticipantBackgroundColor #ECFEFF
skinparam ParticipantBorderColor #06B6D4

actor User
participant "CalendarPage" as CP
participant "ScheduleEventPage" as SP
participant "CalendarController" as CC
participant "CalendarRepository" as CR
database "Drift DB" as DB
participant "NotificationService" as NS
participant "OS Scheduler" as OS

User -> CP : tap + FAB
CP -> SP : open form
User -> SP : fill title, folder, start, reminder
User -> SP : Save
SP -> CC : scheduleMeeting(event)
CC -> CR : scheduleEvent(event)
CR -> DB : insert CalendarEvent
DB --> CR : eventId
CR -> NS : schedule(eventId, reminderAt, payload)
NS -> OS : registerLocalNotification(...)
OS --> NS : ok
NS --> CR : scheduled
CR --> CC : CalendarEvent
CC --> SP : success
SP --> CP : pop + refresh
CP --> User : day cell shows new event

== Reminder fires ==
OS -> NS : notification trigger
NS -> User : push notification
User -> NS : tap notification
NS -> CP : deep-link -> RecordPage(folderId, eventId)
@enduml
```

---

## 3c. Sequence — Open a folder & replay a meeting

```plantuml
@startuml AutoDerdacha_Seq_Replay
skinparam shadowing false
skinparam roundCorner 10
skinparam ParticipantBackgroundColor #FFF7ED
skinparam ParticipantBorderColor #F59E0B

actor User
participant "FoldersPage" as FP
participant "FolderDetailPage" as FD
participant "MeetingDetailPage" as MD
participant "PlayerController" as PC
participant "AudioPlayer\n(just_audio)" as AP
participant "MeetingRepository" as MR
database "Drift DB" as DB

User -> FP : tap folder card (Hero anim)
FP -> FD : push(folderId)
FD -> MR : meetingsIn(folderId)
MR -> DB : SELECT meetings WHERE folder_id=?
DB --> MR : list
MR --> FD : List<Meeting>
FD --> User : list with category color band

User -> FD : tap a meeting
FD -> MD : push(meetingId) (Hero anim)
MD -> MR : getMeeting(id)
MR -> DB : SELECT meeting
DB --> MR : Meeting
MR --> MD : Meeting

User -> MD : tap Play
MD -> PC : play(audioPath)
PC -> AP : load + play
AP --> PC : playing, position stream
PC --> MD : update seek bar
MD --> User : audio playback + Markdown summary

User -> MD : Android back
MD -> PC : pause()
PC -> AP : pause()
MD --> FD : pop
@enduml
```

---
