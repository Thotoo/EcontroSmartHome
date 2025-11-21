## Modbus Configuratie Plan
De Modbus-configuratie in het modbus_client bestand is opgebouwd uit vier lagen die samen het gehele systeem vormen, van de algemene instellingen tot de specifieke registers die worden uitgelezen.

Het begint bij Main, het overkoepelende blok dat de gehele Modbus-client regelt. In dit blok wordt de Modbus-functionaliteit aan of uit gezet en kan debug-informatie worden ingeschakeld. In het voorbeeld is dit als volgt ingesteld:

>config main 'main'
    option enabled '1'   # Modbus-client staat aan
    option debug '0'     # geen debug informatie

Daaronder bevindt zich de laag van RTU Device, de fysieke interface waarop de Modbus-communicatie plaatsvindt. Dit kan bijvoorbeeld een RS485-connector zijn van het kastje zelf. In deze laag worden de communicatiestandaarden ingesteld, zoals baudrate, pariteit, stopbits, flowcontrol en of full duplex aanstaat. Elk RTU-apparaat dat later wordt gedefinieerd, is gekoppeld aan één RTU device. In het voorbeeld:
>config rtu_device '1'
    option name 'Modbus'
    option device '/dev/rs485'
    option baudrate '115200'
    option flowcontrol 'none'
    option databits '8'
    option parity 'none'
    option stopbits '1'
    option full_duplex_enabled '0'
    option enabled '1'

Het ID '1' duidt aan dat dit de eerste RTU device is. Alle apparaten die hierop aangesloten zijn, communiceren via deze instellingen.

Op de volgende laag bevinden zich de RTU Servers, de apparaten die daadwerkelijk op een RTU device zijn aangesloten. Elk apparaat krijgt een uniek Modbus ID (server_id) en wordt gekoppeld aan een RTU device. Ook worden hier uitleesfrequentie en timeout ingesteld. In het voorbeeld:
>config rtu_server '2'
    option name 'EnergieMeter'
    option rtu_device '1'       # gekoppeld aan RTU device 1
    option server_id '154'      # Modbus slave ID van het apparaat
    option frequency 'period'
    option period '5'           # uitleesinterval in seconden
    option timeout '1'
    option skip_on_many_tmos '0'
    option enabled '1'

Het ID '2' verwijst naar het tweede server-item in de configuratie, terwijl server_id '154' het unieke Modbus-adres van het apparaat zelf aangeeft.

Tot slot zijn er de Requests, de specifieke lees- of schrijfacties op een RTU server. Een request koppelt een register of groep registers aan een RTU server en bepaalt de uit te lezen of te schrijven data, de functiecode en het datatype. Ook kan hier worden ingesteld of de data alleen wordt opgeslagen bij verandering, of het een broadcast is, enzovoort. In het voorbeeld:
>config request_2 '3'
    option name 'power_received_l1'
    option rtu_server '2'        # gekoppeld aan RTU server 2
    option function '4'          # Modbus functiecode 4 = lees input registers
    option first_reg '104'       # eerste register
    option reg_count '2'         # aantal registers
    option data_type '32bit_uint1234'
    option store_on_change_only '0'
    option broadcast '0'
    option no_brackets '0'
    option enabled '1'

Het ID '3' verwijst naar deze specifieke request binnen RTU server 2. Deze request leest bijvoorbeeld de ontvangen stroom op fase L1 van registers 104 en 105 van de EnergieMeter.

Het geheel werkt hiërarchisch:
- Main regelt de algemene werking (aan/uit en debug)

- RTU Device bepaalt de fysieke communicatiepoort en instellingen

- RTU Server definieert de apparaten op die poort

- Request bepaalt welke data van die apparaten wordt uitgelezen of geschreven

### Tags en samples

Om het idee te ondersteunen dat de Teltonika eenvoudig op elk soort apparaat kan worden aangesloten, worden voorgeprogrammeerde samples beschikbaar gesteld voor elk type apparaat. Deze samples bevatten kant-en-klare configuraties die direct bruikbaar zijn.

Om het beheer van deze samples eenvoudiger te maken, wordt gebruikgemaakt van de tag-functie uit RMS. Elke tag kan worden gekoppeld aan een specifieke configuration sample, zodat per apparaat of gebruiksscenario snel de juiste configuratie kan worden geselecteerd.

Bij deze configuration samples kunnen aanpassingen worden gemaakt in de standaardconfiguraties. Het is mogelijk om:

Configuraties te verwijderen die niet relevant zijn voor het specifieke apparaat of scenario.

Configuraties aan te passen, bijvoorbeeld door parameters te wijzigen zoals poort, baudrate of uitleesperiode.

Nieuwe configuraties toe te voegen om extra functionaliteit te ondersteunen of speciale use-cases te dekken.

Op deze manier ontstaat een flexibel systeem waarbij standaardconfiguraties kunnen worden hergebruikt, maar ook eenvoudig kunnen worden aangepast aan specifieke apparaten of toepassingen. Het gebruik van tags maakt het bovendien overzichtelijk en snel toepasbaar, zodat de Teltonika in een breed scala aan situaties kan worden ingezet zonder dat handmatig iedere configuratie vanaf nul moet worden opgebouwd.


### Structuur

**RTU Servers**
Elke apparaat heeft een apart modbus id, je kan geen twee apparaten met dezelde id hebben omdat ze anders beide op een request gaan reageren. Dus voor elk verschillend apparaat qua modbus registers moet er een apparte rtu server worden aangemaakt. 

>RTU Server 1 → EnergieMeter, server_id 154
RTU Server 2 → WaterMeter, server_id 180

**Requests**:
Ook voor requests wordt een vaste ID gebruikt per server, bijvoorbeeld:
>Request 1,'1'; → power_received_l1
Request 2,'1' → water_reveiced_l1


#### Voordelen
- Consistentie:
Alle configuraties en samples verwijzen altijd naar dezelfde ID’s, waardoor fouten bij het koppelen van requests of servers worden voorkomen.

- Herbruikbaarheid:
Samples kunnen herhaaldelijk gebruikt worden voor meerdere apparaten van hetzelfde type, omdat de ID-structuur bekend en stabiel is.

- Eenvoudiger beheer:
Beheer van configuraties wordt overzichtelijk, omdat er geen dynamische mapping of placeholder-vervanging nodig is.

 #### Nadelen
 - Kans op ID-conflicten. Als meerdere samples dezelfde ID’s gebruiken voor verschillende apparaten of requests, kan dit leiden tot conflicten en onverwachte gedrag.
 - Complexiteit bij schaalvergroting, Bij een groot aantal apparaten, servers en requests wordt de vooraf gedefinieerde ID-lijst snel omvangrijk en moeilijk te beheren.