<H3>
MONZ80 Updates to David Dunfield’s Z80 Monitor
</H3>

<p>
Here I've started updating David Dunfields MONZ80 found at his webpage:
</p>
https://dunfield.themindfactory.com/
<br>
<br>
<p>
Here is the website for zasm:
</p>
https://k1.spdns.de/Develop/Projects/zasm/Distributions/
<br>
<br>
<p>
The resulting code compiles under ZASM and implements proper segments to 
assist in porting the code to other boards.  Changed here are the comments,
all * comments are converted to ;; comments, which ZASM likes much better.
The relative equates which were EQU * were replaced with EQU $, and various 
parameters were changed to reflect MSB / LSB assignments, along with a number
of case non sensitive label names which had to be updated.
</p>
<p>
The monitor was released by David, and the details for copying are included in
COPY.TXT.  While not open source its fairly re-distributable for personal
use. I have archived his original cross assembler package which can be found on 
his website above.
</p>
<p>
One last modification was the use of the 68B50 UART for the IO commands,
this felt like a more logical choice, given that Grant Serles designs (and
so many others) use this as a default IO chip. 
</p>
<p>
Currently the IO address is pointed at port 0x80.  
</p>
<p>
You can find the code segments at the top for customizing your memory map,
and the io commands are at the bottom of the file:
</p>
<PRE>
code segments:
   USTACK - the user stack (top of RAM) 
   UCODE - the user code area (where the user program is loaded) 
   MDATA - the monitor data area (where the monitor variables are stored)
   MCODE - the monitor code
   _u68B50 - the 68B50 UART driver (found at bottom of this file)
</PRE>
<p>
While this does not have a specific license, it is (C) David Dunfield 1996-2007.
please check out the COPY.TXT file, it includes the expectations and guidelines 
for the distribution of the code.
</p>

<br>

<H3>Disclaimer</H3>

<p>
David, nor myself are not liable for any use of this software,  it is found to 
function and is "AS-IS".  You certainly are quite welcome to provide feedback and 
fixes in the form of a pull request, but under no circumstances should this 
be considered fit for any purpose, function or production use -- though I have
found it quite useful over the years.
</p>
