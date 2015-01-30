# Logexchange
Opensocial Widgets that make use of the Logexchange protocol developed in my bachelors thesis [Near Real-time Visual Community Analytics for XMPP-based Networks](https://gord.in/ba.pdf).

For Information on how the protocol works and what commands are available read section "4.4 XMPP log data Exchange Protocol".
# Setting up the Logexchange Plugin
1. Have a working Prosody XMPP server with mod_logexchange enabled. Follow [the instructions here](https://github.com/Gordin/mod_logexchange/tree/master)
2. Setup the ROLE SDK or any other opensocial container
3. Add these three gadgets in the opensocial container:

    ```
    https://rawgit.com/Gordin/Logexchange/master/NetworkGadget.xml
    https://rawgit.com/Gordin/Logexchange/master/SelectorGadget.xml
    https://rawgit.com/Gordin/Logexchange/master/StatGadget.xml
    ```
Note that these gadgets include hardcoded links to other files in this repository. You'll probably want to deploy all the files somewhere and change the hardcoded links to relative links if you want to make changes.
