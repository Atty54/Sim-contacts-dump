# Sim-contacts-dump

🇷🇺 Русская версия: [README.ru.md](README.ru.md)

---

**Sim-contacts-dump** — a script to extract contact dumps from inactive SIM cards via 3G/4G modems that support AT commands.  
Use case: for example, when cleaning up old SIM cards to save contacts before disposal.

## Requirements
- Windows 10+
- PowerShell with administrator privileges
- 3G/4G modem supporting AT commands

## Features
- Extract all contacts from the SIM
- Supports UCS2 encoding for proper name display
- Saves dumps as text files
- Works sequentially with multiple SIM cards

## Instructions
1. Insert the SIM card into the modem.  
2. Plug the modem into a USB port.  
   - If the modem has a web interface, switch it to AT mode (e.g., Huawei E3276, Megafon M150-1, M100-2, MTS 822F/822FT → Project Mode).  
3. Open PowerShell with administrator privileges.
4. Allow script execution for the current session (so Windows doesn’t block the script):  
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy Process -Force  
5. Type `devmgmt.msc`; in Device Manager, expand "Ports" and note the COM port number assigned to the modem.  
6. Open `sim_dump.ps1` in a text editor and replace `$portName = "COM6"` with your COM port. (Optionally, set the export path in `$exportDir = "C:\SIM_Archive\"`).  
7. Run the script in PowerShell: `.\sim_dump.ps1`.  
8. Wait until the script finishes.  
9. Remove the modem and SIM card.  
10. Repeat for other SIM cards (steps 5 and 6 do not need to be repeated).
