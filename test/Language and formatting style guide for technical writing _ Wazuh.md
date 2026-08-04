# Style guide for technical writing | Wazuh

This style guide provides editorial guidelines for writing clear and consistent documentation to be published by Wazuh. 

Following style rules is essential to being in tune with the company’s voice, which enables users to build trust in Wazuh.

## Using this guide and other resources

This guide is your first stop for Wazuh-specific information. It complements industry resources such as the [Microsoft Writing Style Guide](https://docs.microsoft.com/en-us/style-guide/welcome/) and the [Google developer documentation style guide](https://developers.google.com/style), which document industry-specific and platform-specific standards.

# 

# Wazuh voice and tone

When writing documentation, aim for a natural, friendly, respectful voice and tone without being overly colloquial, pedantic, or pushy.

Aim for a conversational, semi-formal tone rather than a formal one. But remember that the primary purpose of the documentation is to provide information to someone looking for it. We write to scan first and read second. Above all, we make it simple.

Remember that many readers aren't fluent English speakers; many come from different cultures, and your document might eventually be translated into other languages. 

### A few key points for writing with the Wazuh voice

* Get to the point fast. Start with the key takeaway. Put the most important thing in the most noticeable spot. Make choices and the next steps obvious. Give people just enough information to make decisions confidently. 

* Talk like a person. Choose simple, conversational language. Use short everyday words, contractions when needed, and sentence-style capitalization. Avoid unnecessary jargon and acronyms. And never miss an opportunity to find a better word.

* Simpler is better. Everyone likes clarity and getting to the point. Break it up, step it out, and layer. Short sentences and fragments are easier to scan and read. Prune every excess word.

# Tips to help you write clear, concise, and engaging content

Check your work for simplicity, minimalism, and adherence to style basics.

* Short sentences, simple sentences

- Keep the maximum word count in a sentence to fewer than 26 words.

- One idea per sentence. Don't use multiple or complex clauses.

- Avoid using a gerund (-ing) at the beginning of a sentence.

- Put main ideas first and break the material into small units.

- Follow standard English word order, subject-verb-object, with modifiers before or immediately following what they modify.

* Sentence-style capitalization

- Capitalize the first word of a sentence, heading, title, UI term (such as the name of a button or checkbox if it’s written as such in the interface), or standalone phrase.

- Capitalize proper nouns. Use lowercase for everything else.

- Always capitalize the first word of a new sentence. Rewrite sentences that start with a word that's always lowercase, such as code font words.

- When a slash joins words, capitalize the word after the slash if the word before the slash is capitalized. For example, *Country/Region, Turn on the On/Off toggle*.

* Present tense and active voice

- Use the simple present tense. Don't use future tense.

- Use active voice. It shows clearly who or what performs the action.

- Passive voice is okay to use only:

  - To avoid gender-specific pronouns

  - For system actions

  - For the prerequisites of a task

  - In messages and troubleshooting, to avoid blaming the user

* Strong verbs

- Be direct. Get to the action (verb) quickly and cleanly.

- Avoid weak, vague verbs like *be, has, make*, and *do*.

* Consistent language

- Use one term for each concept or action and use it consistently, so that the user can trust the information. Define and use terminology according to the software, this guide, and the terminology list included at the end of this guide.

* Simple adjectives

- Use one adjective to describe a noun.

- Avoid noun strings of more than 3 words

* Parallel structure

- Use parallel construction, especially in bulleted lists, to show the similarity of list items.

- Ensure that your verbs and nouns agree in number, tense, and voice.

- Don’t use periods when the bulleted list is made up of phrases, as in:

  - Amazon Linux 1 and 2

  - CentOS 6 or later

- Use periods when the bulleted list is made up of complete sentences, as in:

  - **Unattended**: This is an automated installation that requires the initial input of the necessary information to perform the installation process through scripts.

  - **Step by step**: This is a manual installation that includes a detailed description of each step of the installation process.

* Pronouns

- Use *you* to address the reader in a friendly and conversational tone, but keep the registry semi-formal. The user is *you*. The organization is *we*.

- Use *we* to present a recommendation, as in *We recommend*.

- Don't use gender-specific pronouns *he* or *she*. Rewrite any sentence to avoid a gender-specific reference. If needed, use the plural, as in *the users…they….*

- Make sure that all pronouns have a clear reference. Don't use *this* or *that* as a pronoun.

* Words to use

- Positive vs. negative statements \- Tell the user what to do instead of what not to do, especially in instructions, cautions, and recommendations.

- Contractions \- Include common contractions for a less formal tone, but use them sparingly. Some common contractions are *don't, doesn't, isn't, aren't,* and *can't*.

- Determiner \- Use a determiner, such as *the, a, an*, and *one*, with nouns and noun phrases when possible. 

- Include *the* before certain interface terms, like the name of a menu or tab, when you use a descriptor after the name, as in *Click the Edit tab*.

- Don't use the word “*the”* when you omit a descriptor after the interface term, as in *Click **OK***.

* Words to avoid

- Don't use *could, should*, or *would*. Instead, use *must* or *can*, or rewrite the sentence.

- Don't use abbreviations for Latin words like *e.g., i.e*., and *etc*. Use the English equivalent or rewrite the sentence. 

- Exception — It's okay to use *vs.* in titles and index entries.

- Avoid inexact words like *"some,*" *"many,*" *"lots,*" *and "various*." However, it's okay to use the word *"multiple"* when describing several options or possible selections.

# Text-formatting summary

This section provides a quick reference for many of the general text-formatting conventions you should follow when writing content for Wazuh documentation.

## Bold

Use bold formatting, \*\***bold**\*\*, for the WUI elements, as in *Click **Deploy a new agent**.*

Bold formatting should be used for highlighted terms in a bulleted list. For example:

- **Unattended**: You can install Wazuh using scripts that automate the installation process. The scripts also perform health checks to verify that the available system resources meet the minimal requirements.

- **Step by step**: This is a manual way of carrying out the installation that includes a detailed description of each step of the process.

  You might use bold formatting to highlight a special word or as an H4 (see the Heading tags entry), but use the format sparingly and only if it’s necessary for clarity. 

## Italic

Use italics formatting, \**italic*\*, when drawing attention to a specific word or phrase, such as when defining terms or using words not with their dictionary meaning but in an instructional sense. For example:

✔ A *Clos network* is a kind of multistage circuit switching network, first formalized by   Charles Clos in 1952\.

✔ Don't use *&* (ampersand) as a conjunction. Use the word *and* instead.

Italicize parameter names. For example, when you refer to the parameters of a method like doSomething(Uri data, int count), italicize *data* and *count*.

## 

## Code font

In ordinary text sentences (as opposed to code samples), use \`\`code font\`\` to mark up most things that have anything to do with code.

Some specific items to put in code font:

| Attribute names and values | Folders and directories |
| :---- | :---- |
| Class names | HTTP verbs |
| Command-line utility names | HTTP status codes |
| Data types | HTTP content-type values |
| Defined (constant) values for an element or attribute | Language keywords |
| DNS record types | Method and function names |
| Environment variable names | Namespace aliases |
| Element names | Placeholder variables |
| Place angle brackets (\<\>) around the element name | Query parameter names and values |
| Filenames, filename extensions (if used), and paths | Text input |

Items to put in ordinary (non-code) font

- Email addresses

- URLs

- Names of products, services, and organizations

  Often, command-line names are spelled the same as the software project or product with which they are associated, with only differences in capitalization. In such cases, use code font for the command and ordinary font for the name of the project or product. For example, *the options for the* curl *command are explained on the curl project website.*

## Heading tags

A heading element implies all the font changes, paragraph breaks before and after, and any white space necessary to render the heading.

The heading elements are from H1 to H5, with H1 being the highest (or most important) level and H5 the least. Each heading element needs to be applied with a defined syntax. Numbered lists/steps

When writing a task, you need to create a numbered list of all the steps that the user must follow to complete it. Steps might include subtext within, but this is optional depending on how you want to present the information. Steps (and substeps) must be introduced by the appropriate tag. Steps can nest substeps, but substeps cannot contain another level of substep. 

**Important** \- To avoid unwanted containers in the final output, the sublist (substep) indentation must match the number of characters before the text content of the parent list. 

For example, in the following sample input, the parent item:

\#. This is step 1 of X.  

Since there are three characters before the word “This” (\#, ., and a space), the child step must also begin with three spaces before its own \#. marker:

**Correct substep**:

\#. This is step 1 of X.  

   \#. This is substep 1a under step 1\. 

## Using quotes                        

When we take texts from external sources, we must identify these texts as quotations and mention the cited sources. To identify them, we must write the quoted text in *italics* and close it in quotation marks. Below is an example of how to do this:

“*Your time is limited, so don't waste it living someone else's life. Don't be trapped by dogma – which is living with the results of other people's thinking,*” said Steve Jobs.

# Language and grammar

A-Z reference for rules and guidelines related to language use and grammar. Look up the basic writing standards for technical content applied to Wazuh.

## Acronyms

Spell out the term for first use in body content, followed by its acronym in parentheses. For subsequent use, use only the acronym.

If an acronym is more familiar than the term, use the acronym.

* First use example:

  Use this authenticator if your organization operates a primary domain

  controller (PDC) or backup domain controller (BDC).

* Subsequent use example:

  The application note includes more information about configuring your PDC.

* Familiar acronym example:

  Use VPN for remote access to network resources.

## Active voice vs. passive voice

Use active voice for a clear, direct, and friendly tone.

✔ You can install the Wazuh agent on different Operating Systems.

✖ The Wazuh agent can be installed on different Operating Systems.

It's OK to use passive voice in specific instances, including:

* To avoid a wordy or awkward construction

* To avoid gender-specific pronouns, he or she

* For prerequisites at the beginning of a task

* For system actions

* When the subject of a sentence is unknown or isn't the focus

* In messages and troubleshooting, to avoid implying that the user is at fault

## Adjectives and adjectival order

When there are two or more adjectives that are from the same group, the word *and* is placed between the two adjectives.

✔ The house is green and red.

When there are three or more adjectives from the same adjective group, place a comma between each of the coordinate adjectives.

✔ My friend lost a red, black, and white watch.

## Audience

Address the reader as you, but use the term *user* in the section title, the short description, or the task step as necessary to make it clear who is performing the action.

## buttons and icons

The words *button* and *icon* have distinct meanings. Don’t use them interchangeably.

* Use the word “*icon”* only to describe a graphic representation of an object that a user can select and open, such as a folder, document, or application. Don’t use the word “*icon”* for options that appear on ribbons or toolbars.

* If an interface element looks like a button and acts like a button (something happens when it is clicked), always call it a button. Don’t call it an icon.

## can vs. might vs. may

Use *can* when you describe actions or tasks that the user can do. Avoid using *can* when referring to actions or tasks Wazuh can do; write *Wazuh does XYZ* rather than *Wazuh can do XYZ*.

Use the word “*might" to express possibility or when an action's result is unknown or* a variable.

Don't use *may*; it indicates permission and isn't appropriate for product documentation.

✔ You can use the */b* option to force a black-and-white screen display.

    Newer applications might run slowly on less powerful computers.

✖ You may use the */b* option to force a black-and-white display.

    Newer applications may run slowly on less powerful computers.

**Tip**: For introductory and conceptual information, include the words *you can* before the verb for a more conversational tone. In a task, however, eliminate the words *you can* for a more direct tone.

## Capitalization

Follow the guidance for capitalization so all content is consistent.

* **Title case** \- This Line is an Example of Title-style Capitalization.

* **Sentence case** \- This line is an example of sentence-style capitalization.

* **lowercase** \- this line is lowercase.

* **Match appearance** \- Capitalize elements as they appear in the interface or on the desktop.

### Capitalization types

The capitalization rules vary for different types of content.

| Case type | Text type | Example |
| :---- | :---- | :---- |
| Title | Marketing-related contentGoogle Ads | *Looking For A Free & Open Source File Integrity Monitoring Tool? Contact Us* |
| Sentence | Section titles | *Step-by-step installation Registering Wazuh agents*  Exception: Match appearance for a UI element or product name in a topic title. |
|  | Table titles | *Required ports* |
|  | Table column headings | *Package type* |
|  | Captions for graphics and images | *Security analytics* |
|  | List items | *Initial node configuration Subsequent nodes configuration Initializing the Elasticsearch cluster* |
| Lowercase | Glossary terms | *environment tier* |
|  | Filename extensions | *Download the .exe file* |
| Match appearance | Product names | *Upgrade Elasticsearch, Filebeat and Kibana* |
|  | Windows, tabs, and pages | *Go to the Account page, and select Billing.* |
|  | Interface elements | *Select **Add billing information** and click **Save**.* |
|  | Keyboard keys | *Press **Ctrl+Q** to close the application. Press **Enter**.* |
|  | File names | *setup.exe* |

### Capitalization after punctuation

* Always capitalize the first word of a new sentence following any end punctuation.

* Avoid beginning a sentence with a case-sensitive lowercase word such as email or filename extensions.

* In a sentence, don't capitalize the word following a colon or em dash unless it's a proper noun.

## click vs. select

Use *click* for buttons (**Next**, **Apply**, **OK**, **Update Now**), tabs, and any hotlink. Don't surround the button name with the words “*the”* and “*button*.”

Use *select* for menus, submenus, lists, options, and checkboxes. Unlike *click*, *select* doesn’t imply a specific method for choosing an item. It refers to keyboard and mouse actions.

Don’t use check or uncheck when selecting a checkbox.

✔Click **OK** to save your changes.

   Select the checkbox for the option you want.

✖ Select the **OK** button to save your changes.

    Check the checkbox for the option you want.

## command line

* Use *type* or *enter* to instruct users to provide data on the command line.

* Hyphenate when used as an adjective, as in *command-line options*.

* Exception: Don't hyphenate the term command line interface.

  ✔ On the command line, enter the name of the file.

      At the command line, type your password.

      You can run command-line options remotely.

      Use the command line interface to view connected agents.


## Contractions

Contractions present a natural, less formal tone, but use them sparingly.

Never form a contraction from the company name, product name, or any proper noun, for example:

✖ Wazuh’s the best software on the market.

Commonly used contractions are:

* isn’t, aren’t

* can’t

* doesn’t, don’t, didn’t

* hasn’t, haven’t, hadn’t

* wasn’t, weren’t

* won’t

## Dangling modifiers

A dangling modifier is a word or phrase that refers to (modifies) the wrong noun or a noun not clearly stated in the sentence, which leads to confusion.

Make sure that the subject of the sentence is obvious and that the person or thing performing the action is clear.

✖  When modifying a protected file, Wazuh sends this information to the manager and triggers a response.

	*Who modifies the protected file?* 

	*Is it the user or is it Wazuh?*

In this example, two actors are carrying out different actions. An actor is the one that modifies a protected file and Wazuh is the one sending the information and triggering the response.

✔ When *an attacker* modifies a protected file, Wazuh sends this information to the manager and triggers a response.

## Date formats

When you write dates, spell out the month and use a comma between the day of the month and the year. Don't use a comma if you present only the month and year.

Dates are localized according to language preferences. Spell out the month to avoid any confusion.

✔  June 24, 2021

    Install the update before March 2022\.

## either, both

The words *either* and *both* explicitly indicate two items. Use them only when presenting two choices. Otherwise, use phrases like *one of the following* or *these items*.

## Ellipses (...)

When referring to a button or menu item that has an ellipsis, don’t include the ellipsis.

✔ Click **Browse** and navigate to the backup file.

   From the **File** menu, select **Open**.

✖ Click **Browse...** and navigate to the backup file.

                From the menu bar, select **File** and then **Open ....**

## email

Electronic mail, *email*, is one word without hyphenation. It is always lowercase, except when used as the first word of a sentence.

## enter vs. type

In technical content, the terms *enter* and *type* describe the methods of adding text.

Use *enter* to describe inputting information in a field or at a command line. For this kind of information, you can type, copy and paste, or drag and drop.

Use *type* only to enter a literal string (using keyboard keys) at a command line.

✔ At the command line, type /home/username/.ssh/authorized\_keys

## etc.

Don't use it. Rewrite to use *including*, *such as*, or *like*.

✔ The table lists information such as category, class type, and type.

✖ The table lists category, class type, etc.

## feature vs. component, feature vs. enhancement

The terms *feature*, *component*, and *enhancement* are often used interchangeably, but each has a distinct meaning.

A *feature* is a unit of functionality of a product that is defined by a requirement. Product overview sections describe the major areas of functionality. Wazuh has 10 major functionalities defined as *capabilities*. These capabilities include, and should be written as:

* File integrity monitoring

* Malware detection

* Security Configuration Assessment

* Active Response

* Log data collection

* Vulnerability detection

* Command monitoring

* Container security

* System inventory

* Agentless monitoring

A software *component* is a modular part of the product architecture. Examples of product components are:

* Wazuh server

* Wazuh agent

* Wazuh repository

## Filename and extension

When referring to the file type only, begin with a period (dot) followed by the filename extension in lowercase. Use the article (*a* or *an*) that applies to the sound of the first letter of the extension *(a .com file* and *an .exe file*). 

Sometimes the file name extension refers to the file type and the extension corresponds to the abbreviation of the generic term for the file. Don't confuse the abbreviation with the file name extension. For example, a *.dll file* (not a DLL file) contains a *DLL*.

✔ Double-click the **setup.exe** file.

    Extract the .zip file.

## folder names

Capitalize folder names according to how they appear on the screen.

Don't apply any special font to a folder name. If the user is selecting a folder, use bold \*\***bold**\*\*.

✔ You can find the files saved in the Default folder

    Double-click the **Program Files** folder.

## Hyphenation rules

Use hyphens sparingly. The guiding principle is to avoid the hyphen unless the result is a spelling mistake or causes confusion. Always consider readability.

Follow these guidelines for using a hyphen with a prefix or a compound word.

### Prefixes

* Use a hyphen if the results are confusing or can be misread.

* Use a hyphen before a proper noun.

  ✔ non-Wazuh products

* Use a hyphen if combining the prefix and stem word results in a double *i* or double *a*.

  For example, anti-inflammatory, meta-analysis

### Compound words

* Use a hyphen when a compound precedes the noun.

  ✔ up-to-date software

      drop-down list

      customer-facing content

      on-access scan

  ✖ denial of service attack


* Don't use a hyphen when a compound follows the noun.

  ✔ The software is up to date.

  ✖ The most recent attack was a denial-of-service.


* Don't use a hyphen between an adverb ending in \-ly and an adjective.

  ✔ recently completed scan

* When using title case, capitalize both words of a compound word.

  ✔ Post-Installation Tasks

When in doubt, look up a word in the [dictionary](#heading=h.p6ta7j1x1b9x).

## if / then

When you start a sentence with *if*, you don’t need to include *then* in the outcome clause because it is implied.

✔ If you do ABC, you can do XYZ.

✖ If you do ABC, then you can do XYZ.

## Keyboard key combinations

For keyboard key combinations like shortcut keys, use a plus sign (+) with spaces between each key:

* Don't use a hyphen  
* Use title capitalization and \*\***bold\*\*** for the shortcut keys  
* Leave the plus sign (+) not bolded

In the example **Alt** \+ **O**, the user presses and holds down **Alt**, then presses **O**.

## later vs. higher

Use *later* for product versions, as in “Wazuh 4.1.2 or later.”

Be careful when using the term *later*. The phrases “*and later”* and “*or later”* might imply that the feature is included or supported in all future releases. To avoid this situation, list each supported version, or add “*up to”* before the version number, and *“or earlier”* after.

Use higher to indicate more powerful hardware, as in “Pentium or higher.”

## Latin abbreviations

Don't use Latin abbreviations such as *etc., e.g., i.e.*, except for *vs*. in section titles.

## Lists

We use two basic types of lists: *ordered* (numbered) and *unordered* (bulleted). Numbered lists present sequential information, like steps in a task and tasks in a process. Bulleted lists present non-sequential information. 

### Bulleted lists

Use these basic rules for bulleted lists.

* Introduce a list with a sentence ending with a period or a fragment ending with a colon.

* This introductory sentence is not the section's short description, which never ends in a colon and is never used to introduce a list. The short description must stand on its own.

* Begin each list item with a capital letter (except for a proper noun that starts with a lowercase letter).

* Make all list items parallel in structure.

  * If one list item is a complete sentence, make sure that each item in that list is a complete sentence that ends with a period.

  * If one list item is a sentence fragment, make sure that each item in that list is a sentence fragment with no end punctuation.

* Don't treat the list and its introduction like one continuous sentence.

  * Don't use semicolons or commas to end list items, and don't insert “*and”* before the last list item.

### Numbered lists

Use these basic rules for numbered lists.

* Don't introduce a numbered list with an introductory sentence or fragment that starts with an infinitive (*To do ABC*) and ends with a colon.

* Begin each list item with a capital letter (except for proper nouns that start with a lowercase letter).

* End each list item with the correct end punctuation. Use a period for complete sentences or a colon when the numbered item introduces a sublist.

✔  Configure settings for global updates.

1. Set the status to **Enabled** and specify a **Randomization interval** between 0 and 40 minutes.  
2. Specify which **Package types** to include in the global updates:  
* **All packages**: Include all signatures, engines, updates, and service packs.  
* **Selected packages**: Limit the signatures, engines, and updates included in the global update.  
3. Click **OK** to save the changes.

To see the text formatting that applies to lists, see the [Numbered lists/steps](#heading=h.eky1ldze8c4l) entry and the [Tasks and steps](#tasks-and-steps) section.

## Log in, login

Use the verb *log in* to connect to a network.

Use the adjective *login* for a description of the screen where you enter (log in) your username and password.

Don't use *log on, logon, log onto, log off of, logout*.  The only exception is to quote the interface.

## Measurements

When you present measurements in your documentation, follow the rules for consistency and readability.

* Always abbreviate a measurement unit that includes an amount (*30 ft*).

* Spell out a measurement unit that doesn't include an amount (*gigabytes*).

* Don't include a period with an abbreviation for measurement, except for inches (*in*.).

* Use the same abbreviation for a measurement unit whether the amount is singular (*1 in.*) or plural 2 in.).

* Insert a space between the amount and the measurement unit *(35 mm*).

## parenthesis (s), parentheses (pl)

We allow parenthetical phrases, but use them sparingly. Often, you can rewrite a sentence to avoid the need for a parenthetical phrase.

Don't enclose a complete sentence or a paragraph in parentheses. If the sentence or paragraph is complete, incorporate it into the flow of information. Otherwise, consider carefully if the information is needed or helpful.

## path

A path specifies the location in a file system. A path starts at the root or is relative to a location other than the root. Capitalize the path as it appears on the screen. Separate each folder with a forward slash or backslash, as appropriate. If a drive precedes the path, capitalize the drive letter and follow it with a colon and a forward slash or backslash.

Don't apply any special font, unless you instruct the user to type the path in a field or at a command line, in which case you would use the code font specified for user input.

✔ The default location is the C: drive.

     Look in the C:\\Documents and Settings\\user1 directory.

     At the command line, type /home/username/.ssh/authorized\_keys

## please

Don't use the word *please* when instructing the user to complete a task. Include the word only when referencing the interface or a system message.

## Possessives

Don't form a possessive of company names, product names, or feature names.

✔ The Wazuh agent

✖ The Wazuh’s agent

## Prepositions

Ending a sentence with a preposition is okay, mainly to avoid awkward construction.

#### Prepositions and collocations 

| Use this preposition... | With this noun or verb... | Example |
| :---- | :---- | :---- |
| at | command prompt | at the command prompt |
| from | list | from the drop-down list |
|  | menu | from the **Wazuh Kibana** menu |
| in | column | in the column |
|  | dialog box | in the dialog box |
|  | field | in the field |
|  | file | in the file |
|  | interface | in the interface |
|  | list | in the list |
|  | pane | in the pane |
|  | table | in the table |
|  | window | in the window |
| on | command line | on the command line |
|  | menu bar | on the menu bar |
|  | network | on the network |
|  | page | on the page |
|  | screen | on the screen |
|  | server | on the server |
|  | tab | on the tab |
|  | toolbar | on the toolbar |
|  | install | install Wazuh on the endpoint |
| to | deploy | deploy the software to the endpoint |
|  | send | send a message to the user |

## Pronouns

Follow the pronoun usage rules for consistent content that adheres to our standards.

### Gender

Don't use gender-specific pronouns (*she, he*) or new gender-neutral pronoun styling (*s/he*). To avoid awkwardness, use:

* Second-person pronoun, *you*

* *The user, users*

* Plural, *they*

Also, remember that the user is *you,* and Wazuh is *we*.

### Unspecified

Ensure that the pronouns you use (such as *it*) are obvious as to which nouns they reference. When in doubt, rewrite the sentence to avoid any ambiguity

## Punctuation

Follow the rules for different types of punctuation.

### Commas (,)

Use a serial comma before the conjunction in a list of three or more items.

✔ Wazuh is a free and open source platform for threat detection, security monitoring,           incident response, and regulatory compliance.

### Periods (.)

In short descriptions, body text, numbered lists, and steps, always write a complete sentence followed by a period.

In a bulleted list, always use a period at the end of a list item that is a complete sentence. If one list item is a complete sentence, make each item in that list a complete sentence ending with a period. 

In reference tables, use a period at the end of a sentence fragment and a complete sentence. Punctuate bulleted lists according to list style, using complete sentences with periods or fragments with no ending punctuation.

### Colons (:)

Use a colon at the end of a sentence or fragment that introduces a list, a path, user input, or sample code.

Don't use a colon:

* To introduce an image, a table, or sections

* At the end of a task title

* At the end of a short description

* If the previous or next paragraph ends in a colon

### Punctuation and formatting

Set punctuation (colon, comma, period, semicolon, question mark, exclamation point) in the same font as the paragraph text, even if the word preceding the punctuation uses a special font.

## Recommendations

Use a recommendation to present a tip for the best results. When possible, present a positive recommendation.

When presenting a suggestion, use the pronoun *we* as in, *We recommend that you back up your system before you install the software.*

Present the recommendation as a positive statement.

✔ We recommend that you use lowercase.

✖ We don't recommend using uppercase.

## Variables

Variables are placeholders. Surround a variable in angle brackets, separate the words with underscore and use upper case.

✔ Type cf usage type=\<USAGE\_TYPE\> , where \<USAGE\_TYPE\> is what you want to run the report against.

## version

When using the name of a product and its version number, don't include the word version.

Use the word *version* only when the product name isn't included.

✔ Wazuh Kibana plugin is now compatible with Wazuh 4.1.5.

    This section lists the changes in version 4.1.5.

✖ Wazuh version 4.1.5 resolves these issues.

     Wazuh Kibana plugin is now compatible with Wazuh v.4.1.5

## window, page, tab

The terms *window, page, tab, dialog box,* and *pop-up* indicate parts of the interface where you view, enter, click, or select something. You can use different terms to distinguish between platforms or between views.

### window

A *window* is the fixed part of a client-based application interface. If it contains options that a user can enter, click, or select, it is still called a window. If the application interface has a navigation tree in the left pane, the right pane is called a *window*.

* Capitalize as it appears in the interface and use \*\***bold**\*\*.

* You enter information *in* a window.

### page

A *page* is the main part of a web-based application interface that is viewed in a browser. If it contains options that a user can enter, click, or select, it is still called a page. If the application interface has a navigation tree in the left pane, the right pane is called a page.

* Capitalize as it appears in the interface and use \*\***bold**\*\*.

* You enter information *on* a page.

### tab

Tabs appear within a window or page. Use the term *tab* for both the label you click and the view you see after clicking the label.

* Capitalize as it appears in the interface and use \*\***bold**\*\*.

* You enter information *on* a tab.

  ✔ Click the **Company** tab.

      On the **Company** tab, enter the customer contact information.

# Writing different types of section elements

A Wazuh documentation section comprises separate elements designed to help the reader navigate through the information in a clear and easy-to-understand manner. Consistency is key in enabling users to build trust in the information we present and improving search engine optimization (SEO).

### Elements:

- Meta descriptions

- Titles

- Short descriptions

- Prerequisites

- Tasks and steps

- Tabs

- Next steps

## Meta descriptions

A meta description is an element that describes and summarizes the contents of your page for the benefit of users and search engines. It needs to be introduced with .. meta:: :description:

### Best practices for writing meta descriptions

* Extension: Keep the text between 120 and 150 characters. Do not exceed 150 characters to avoid cutting the text short.

* The text should describe the content or what you achieve with the section's content.

* Use CTA (Call To Action) verbs when possible. For example, *check out..., learn more..., visit..., discover..*

* When writing meta descriptions, try to include SEO keywords. SEO keywords are the words and phrases in our documentation content that make it possible for people to find the Wazuh website via search engines.

  Sample meta description for the Wazuh user manual index page: 

    
  .. meta:: :description: Wazuh is a comprehensive open source cybersecurity platform. In our user manual, you can learn how to configure and use each Wazuh component. 

## 

## Titles

Accurate, concise, and consistent \[section\] titles are important for search results and search engine optimization (SEO). Meaningful titles help users find the information they need quickly and help search engines understand what a section is about.

### Best practices for writing titles

* Extension: Keep the text between 50 and 70 characters (8 words max.). 

* Put important keywords first: Put the most important and distinctive information at the beginning of the title rather than the end.

* Use consistent phrasing: A well-written section title helps users understand what the section covers, and helps identify the kind of information the section contains. From the title, users know whether the section might help them understand something, help them do something, or provide supporting information. This distinction is made by phrasing titles uniquely for each section type.


| Type of title  | Guideline | Example |
| :---- | :---- | :---- |
| Index title (for groups of related sections) | Start with a descriptive noun phrase, one noun, or a gerund. Replaces initial overview section. | *Getting startedInstallation guideRegistering Wazuh agentsUpgrading the Wazuh manager* |
| Concept title (for \[sub\]sections focused on descriptive information, not instructions) | Start with a descriptive noun phrase or verb phrase. Answers the question *What is this?, How does this work?, Why do this?,* or *When to do this?* | *Installation methods More installation alternatives Deployment types* |
| Task titles (for \[sub\]sections with instructions to complete a task) | Start with an imperative (command) verb. Answers the question How do I? | *Upgrade Elasticsearch, Filebeat, and Kibana Update ruleset Detect filesystem changes How to configure Kibana* |
| Reference (for \[sub\]section titles that categorize or label the content) | Start with a noun or adjective, and include the reference construct (for example, table, list). States what the reference objects are. | *Supported operating systems Packages list Makefile options* |


* Make titles easy to read: Remove unnecessary words and focus on clarity.

- Don't start titles with an article (*A, An, The)*.

- Use the plural (*Generating automatic reports*), unless only one object can exist (*Installing Filebeat*).

- Don't start concept titles with generalized phrases (*Understanding, About, or Working with*).

- For task titles, focus on the goal of the procedure, not the interface element.

- Use plain language.

- Make sure that titles can be understood out of context.

- Use sentence case and follow the capitalization of case-sensitive terms such as UNIX.

- Don't use ampersands (&).

- Don't include copyright symbols.

- If you use a colon (:) or em dash (—) in a title, capitalize the word that follows, regardless of its part of speech.

## Short descriptions

As the first paragraph of every section, concise and complete short descriptions allow users to quickly decide whether to read on. Short descriptions provide users with an understanding of what the section contains and help them navigate through the documentation more efficiently.

###  Best practices for writing short descriptions

* Focus on the theme or purpose of the section— the what and why.

* Make sure that the paragraph makes sense when viewed with its title only.

* Make the short description concise and complete.

* Use complete sentences.

* Don't restate the title.

* Don't state the obvious.

* Don't mention the section itself: "This section describes...," "This document includes...," or "Use this task to..."

* Don't use it as a lead-in to a list, and don't punctuate with a colon (:).

* Different types of information require unique approaches to writing short descriptions.


| Type of section | Guideline | Example |
| :---- | :---- | :---- |
| Index/Concept | Answers these questions: • What is this? • Why is it important? | Global administrators have read and write permissions, and rights to all operations. A global administrator account is created automatically during installation. |
| Task | Answers these questions: • What are the benefits of the task? • Why perform the task? • When does the task need to be performed? Don't describe how or where to perform the task. Save that information for the steps. | To store your passwords, you must create a database and protect it with a master password. |
| Reference | Answers these questions: • What are the items? • What do they do? • What are they used for? | You can customize your installation by following the unique requirements and options for each scenario. |

## Prerequisites

Prerequisites specify anything that the user needs to know or do before starting the task. They can describe actions that must be completed before beginning the task or list equipment that the user needs to complete the task. You might also use them as a container for warning and note statements specific to the entire task. If needed, you can include elements such as unordered lists, paragraphs, notes, and tables in the element.

## Tasks and steps {#tasks-and-steps}

Tasks provide instructions for completing specific procedures. The instructions detail what to do and the correct order to do it.

Tasks typically contain:

* Information immediately required to complete a single procedure.

* Minimal conceptual information that is required to understand the task.

* Prerequisites for completing the task.

#### 

### Best practices for writing tasks

* Include instructions only for a single task.

* Use an imperative verb to start the title of a task.

* Introduce the task and provide the background information required to complete the task.

  * Describe *what* and *why*, not *how* or *where*.

* Start every task from the beginning. Don't assume that the user has already opened a window or performed the preceding action in an earlier task.

* Include requirements for the task (for example, administrator rights) as prerequisites before the steps.

* Limit tasks to 7–10 steps.

  * For a lengthy and complex task with multiple subtasks, break it up into separate task topics. Present them in order and explain that the task must be performed in that order.

* Don't tell the user to repeat steps. Instead, write an inclusive introduction that gives context for the information.

  ✔ Complete these steps to check in each extension.

* If your task doesn't have numbered steps, consider whether the \[sub\]section might instead be a concept.

### Step guidelines

* Write steps in the imperative voice.

* Limit steps to one sentence.

* Don't include descriptions of interface elements when the user can see them on the screen.

* Don't use interface labels as generic nouns or verbs.

  ✔ Type a user name and password.

  ✖ Type a **User Name** and **Password**.

* For optional actions under a step, use a bulleted list.

* Only include the result of a step if it helps avoid confusion.

  ✔ The list of systems is displayed in the details pane.

  ✖ The Preferences page opens.

To see the text formatting that applies to steps, see the [Numbered lists/steps](#heading=h.eky1ldze8c4l) entry.

# 

# Writing Wazuh rules

When writing Wazuh rules, our convention is that the rules should begin with the ID of 100000 and above. We recommend using the [rule.id](http://rule.id) range of 100000 \- 120000\.

Always flag instances of whenever these deprecated terminologies are used within descriptions:

OpenSCAP

OpenSearch

Kibana

ElasticSearch

