import datetime
import logging
import time
import os
import json
from typing import List
from math import *    

import azure.functions as func

def main(sineGenerator: func.TimerRequest,
         eventHubMsg: func.Out[str]):

    Frequency=80                                                                  
    Frequencydelay=.1 
    pi=3.1415926535897932384626433832795028841971693993751057   

    timestamp = datetime.datetime.utcnow
    logging.info('Python timer trigger function ran at %s', timestamp)

    msgs=[]
    for n in range(Frequency):                                                
        p=sin(2*pi*n/Frequency)*100
        msgs.append('{"p":%i}' % (p))                                                                                      
        time.sleep(Frequencydelay)
    
    eventHubMsg.set(json.dumps(msgs))
    