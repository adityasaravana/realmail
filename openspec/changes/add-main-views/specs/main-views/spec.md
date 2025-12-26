# Main Views

## ADDED Requirements

### Requirement: Three-Column Layout
The app SHALL use NavigationSplitView for the standard three-column email client layout.

#### Scenario: App Layout
- Given the app is launched
- When the main window appears
- Then three columns are visible
- And sidebar shows accounts/folders
- And content shows message list
- And detail shows selected message

### Requirement: Sidebar View
The sidebar SHALL display accounts with their folder hierarchies and unread badges.

#### Scenario: Account Display
- Given configured accounts
- When viewing sidebar
- Then each account is shown as a section
- And folders are nested under accounts
- And unread counts are shown as badges

#### Scenario: Folder Selection
- Given folders in sidebar
- When a folder is clicked
- Then the message list updates
- And the folder is highlighted

### Requirement: Message List View
The message list SHALL display messages with sender, subject, date, and preview.

#### Scenario: Message Display
- Given a selected folder with messages
- When viewing message list
- Then messages are shown in reverse date order
- And unread messages are visually distinct
- And preview text is shown

#### Scenario: Swipe Actions
- Given a message in the list
- When swiping left or right
- Then quick actions appear
- And delete, archive, flag are available

### Requirement: Message Detail View
The message detail SHALL show full message content with headers and attachments.

#### Scenario: View Message
- Given a message is selected
- When viewing detail pane
- Then headers show from, to, date, subject
- And body content is rendered
- And attachments are listed

#### Scenario: HTML Rendering
- Given a message with HTML content
- When viewing detail
- Then HTML is rendered via WKWebView
- And external images are optionally loaded

### Requirement: Compose View
The compose view SHALL allow creating new messages with recipients, subject, and body.

#### Scenario: New Message
- Given the user clicks Compose
- When compose window opens
- Then From shows active account
- And To, CC, BCC fields are available
- And body editor is ready

#### Scenario: Recipient Autocomplete
- Given the user types in To field
- When matching contacts exist
- Then suggestions are shown
- And selection fills the field

### Requirement: Reply/Forward Actions
The app SHALL support reply, reply all, and forward from selected messages.

#### Scenario: Reply
- Given a message is selected
- When Reply is clicked
- Then compose opens with quoted content
- And To has original sender
- And subject has "Re:" prefix

#### Scenario: Forward
- Given a message is selected
- When Forward is clicked
- Then compose opens with quoted content
- And To field is empty
- And subject has "Fwd:" prefix

### Requirement: Keyboard Navigation
The app SHALL support standard keyboard shortcuts for navigation and actions.

#### Scenario: Arrow Navigation
- Given message list is focused
- When up/down arrows are pressed
- Then selection moves through messages

#### Scenario: Shortcuts
- Given the app is active
- When Command+N is pressed
- Then new compose window opens
- And Command+R replies to selected

### Requirement: Search Functionality
The app SHALL support searching messages within folders.

#### Scenario: Search Messages
- Given the search field is active
- When the user types a query
- Then messages are filtered in real-time
- And matching results are shown

### Requirement: Toolbar Actions
The app SHALL have a toolbar with common mail actions.

#### Scenario: Toolbar Buttons
- Given the main window
- When viewing toolbar
- Then compose, reply, delete buttons are visible
- And refresh/sync action is available

### Requirement: Settings View
The app SHALL provide settings for account management and preferences.

#### Scenario: Access Settings
- Given the app menu
- When Settings is selected
- Then settings window opens
- And account list is shown
- And preferences are configurable

### Requirement: ViewModels
Views SHALL use @Observable view models for state management.

#### Scenario: MailboxViewModel
- Given a MailboxViewModel
- When folders or messages change
- Then views automatically update
- And loading states are reflected

#### Scenario: ComposeViewModel
- Given a ComposeViewModel
- When composing a message
- Then draft state is managed
- And send action is available

### Requirement: Empty States
The app SHALL show appropriate empty states when no content is available.

#### Scenario: No Accounts
- Given no accounts configured
- When app launches
- Then empty state prompts to add account

#### Scenario: Empty Folder
- Given an empty folder selected
- When viewing message list
- Then empty state indicates no messages
