<H3>
MONZ80 Updates to David Dunfields Z80 Monitor
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
The relitive equates which were EQU * were replaced with EQU $, and various 
paramiters were changed to reflect MSB / LSB asignments, along with a number
of case non sensitive lable names which had to be updated.
</p>
<p>
The monitor was released by David, and the detils for copying are included in
COPY.TXT.  While not open source its fairly re-distributable for personal
use. I have archived his original cross asembler package which can be found on 
his website above.
</p>
<p>
One last modification was the use of the 68B50 UART for the IO commands,
this felt like a more logical choice, given that Grant Serles designs (and
so many others) use this as a defalut IO chip. 
</p><br>
Currently the IO address is pointed at port 0x80.  
<br>
You can find the code segments at the top for customizing your memory map,
and the io commands are at the bottom of the file:

<code>
;; code segments:

;;   USTACK - the user stack (top of RAM) 
;;   UCODE - the user code area (where the user program is loaded) 
;;   MDATA - the monitor data area (where the monitor variables are stored)
;;	 MCODE - the monitor code
;;   _u68B50 - the 68B50 UART driver (found at bottom of this file)
</code>
<p>
While this does not have a specific licence, it is (C) David Dunfield 1996-2007.
please check out the COPY.TXT file, it includes the expectations and guidelines 
for the distrbution of the code.
</p>

<br><br>

<H3>Disclaimer</H3>

<p>
David, nor myself are not liable for any use of this software,  it is found to 
function and is "AS-IS".  You certainly are quite welcome to provide feedback and 
fixes in the form of a pull request, but under no cercomstances should this 
be considered fit for any purpose, function or production use -- though I have
found it quite usefull over the years.
</p>
