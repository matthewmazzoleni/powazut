Clear-Host

while ($true) {
    # Display the menu
    Write-Host "Menu Options:"
    Write-Host "1. Connection"
    Write-Host "2. WebApp creation"
    Write-Host "3. FunctionApp Creation"
    Write-Host "4. Info"
    Write-Host "0. Exit"
    
    # Ask the user for a selection
    $selection = Read-Host "Please select an option (0-3)"

    # Process the selection
    switch ($selection) {
        "1" {
                
                break
            }
        "2" { 
                . .\webapp.ps1
                break
            }
        "3" { Write-Host "You selected Option 3"; break }
        "0" { Write-Host "Goodbye!"; exit }
        default { Write-Host "Invalid selection. Please try again." }
    }

    # Optional pause and screen clear
    Read-Host "Press Enter to continue..."
    Clear-Host
}