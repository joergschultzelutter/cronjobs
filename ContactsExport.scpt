on run argv
   -- Zielordner auf dem Schreibtisch festlegen
   set desktopFolder to (item 1 of argv as string)
   set targetFolderName to (item 2 of argv as string)
   set desktopPath to desktopFolder & targetFolderName & ":"

   tell application "Contacts"
       repeat with cardPerson in people
           set personName to name of cardPerson
           set companyName to organization of cardPerson
     
           -- Namen bestimmen (Firma oder Person)
           set baseName to "Unbekannt"
           if companyName is not missing value then
               set baseName to companyName
           end if
           if personName is not missing value then
               set baseName to personName
           end if
 
           -- Sonderzeichen aus dem Dateinamen entfernen
           set baseName to my cleanName(baseName)
        
           -- Prüfen ob Datei existiert und ggf. nummerieren
           set counter to 1
           set fileName to baseName & ".vcf"
           set filePath to desktopPath & fileName
        
           tell application "System Events"
               repeat while (exists file filePath)
                   set fileName to baseName & "_" & counter & ".vcf"
                   set filePath to desktopPath & fileName
                   set counter to counter + 1
               end repeat
           end tell

           -- vCard exportieren
           set vcardData to vcard of cardPerson as text
        
           try
               set outFile to open for access file filePath with write permission
               set eof outFile to 0
               write vcardData to outFile as «class utf8»
               close access outFile
           on error
               try
                   close access file filePath
               end try
           end try
        end repeat
   end tell
   tell application "Contacts" to if it is running then quit
end run

-- Hilfsfunktion für saubere Dateinamen
on cleanName(txt)
    set illegalChars to {":", "/", "\\", "*", "?", "\"", "<", ">", "|"}
    repeat with c in illegalChars
        if txt contains c then
            set AppleScript's text item delimiters to c
            set textItems to text items of txt
            set AppleScript's text item delimiters to "_"
            set txt to textItems as string
        end if
    end repeat
    return txt
end cleanName
