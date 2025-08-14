# WiFi Control Setup Notes

After setting up the WiFi control commands, make sure to:

1. Make the script executable:
   ```bash
   chmod +x script/wifiToggle.sh
   ```

2. Configure admin access in config.ini:
   ```ini
   [bbs]
   bbs_admin_list = your_node_id_here
   ```

3. Enable shell commands in config.ini:
   ```ini
   [fileMon]
   enable_runShellCmd = True
   ```

4. Test the script manually first:
   ```bash
   ./script/wifiToggle.sh
   ```

The script automatically makes itself executable when called, but manual setup is recommended for security.

## Usage
- Send `wifi` via DM to toggle WiFi
- Send `wifion` via DM to force WiFi on  
- Send `wifioff` via DM to force WiFi off
- Send `wifi?` via DM for help

Only admin users can control WiFi for security.