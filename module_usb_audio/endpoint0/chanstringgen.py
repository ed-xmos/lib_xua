

def genstrings(outputChanCount, chanString, portString, structureString):
    
    for i in range(1,outputChanCount):

        print "#if (NUM_USB_CHAN_{c} > {iteration}-1) \n\
    #if (!defined(SPDIF_{p}) || ({i} > (SPDIF_{p}_INDEX+2)) || ({i} <= SPDIF_{p}_INDEX)) && (({i} > (ADAT_{p}_INDEX+8)) || (!defined(ADAT_{p})) || ({i} <= ADAT_{p}_INDEX))\n\
        .{s}ChanStr_{i}          = \"Analogue {iteration}\", \n\
    #elif defined(ADAT_{p}) && defined(SPDIF_{p}) && ((SPDIF_{p}_INDEX+2) < ADAT_{p}_INDEX)\n\
        .{s}ChanStr_{i}          = \"Analogue {iteration}/SPDIF/ADAT\",\n\
    #elif(SPDIF_{p}_INDEX < I2S_CHANS_DAC) && defined(SPDIF) \n\
        .{s}ChanStr_{i}          = \"Analogue {iteration}/SPDIF\",\n\
    #elif(ADAT_{p}_INDEX < I2S_CHANS_DAC) && defined(ADAT_{p}) && ({i} <= ADAT_{p}_INDEX+8)\n\
        .{s}ChanStr_{i}          = \"Analogue {iteration}/ADAT\",\n \
    #elif defined(SPDIF_{p}) && defined(ADAT_{p}) && ((SPDIF_{p}_INDEX + 2) < (ADAT_{p}_INDEX))\n\
        .{s}ChanStr_{i}          = \"SPDIF/ADAT\",\n\
    #elif((SPDIF_{p}_INDEX < {i}) && ({i} <= SPDIF_{p}_INDEX+2) && defined(SPDIF_{p})) \n \
        .{s}ChanStr_{i}         = \"SPDIF\",\n\
    #elif((ADAT_{p}_INDEX < {i}) && defined(ADAT_{p}))   \n\
        #if({i} - ADAT_TX_INDEX == 1) \n\
        .{s}ChanStr_{i}          = \"ADAT 1\", \n\
        #elif({i} - ADAT_TX_INDEX == 2) \n\
        .{s}ChanStr_{i}          = \"ADAT 2\", \n\
        #elif({i} - ADAT_TX_INDEX == 3) \n\
        .{s}ChanStr_{i}          = \"ADAT 3\", \n\
        #elif({i} - ADAT_TX_INDEX == 4) \n\
        .{s}ChanStr_{i}          = \"ADAT 4\", \n\
        #elif({i} - ADAT_TX_INDEX == 5) \n\
        .{s}ChanStr_{i}          = \"ADAT 5\", \n\
        #elif({i} - ADAT_TX_INDEX == 6) \n\
        .{s}ChanStr_{i}          = \"ADAT 6\", \n\
        #elif({i} - ADAT_TX_INDEX == 7) \n\
        .{s}ChanStr_{i}          = \"ADAT 7\", \n\
        #elif({i} - ADAT_TX_INDEX == 8) \n\
        .{s}ChanStr_{i}          = \"ADAT 8\", \n\
        #else \n\
        .{s}ChanStr_{i}          = \"ADAT \",\n\
        #endif\n \
    #endif \n\
#endif\n\n".format(iteration=i, i=i, c=chanString, p=portString, s=structureString)

    return;

print "/* AUTOGENERATED using stringtable.py */ \n\n"

print "/* Output Strings */\n\n"

genstrings(32, "OUT", "TX", "output");

print "/* Input Strings */\n\n"

genstrings(32, "IN", "RX", "input");
