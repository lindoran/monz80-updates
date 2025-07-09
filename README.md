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
The tabbing and spacing of the original files have left the code in a slightly 
"mangled but assembling" state. I will try to poke at this from time to time but, 
the goal here was simply to get the code to assemble under something slightly 
more modern; which was done. If you do find the chance to do a pull request please 
feel free to fix the section of the code you are working in. I would surely 
appreciate it, though ill get through this eventually. 
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
<UL>
   <LI>
     <CODE>USTACK</CODE> - the user stack (top of RAM)
   </LI>
   <LI>
     <CODE>UCODE</CODE> - the user code area (where the user program is loaded)
   </LI>
   <LI>   
      <CODE>MDATA</CODE> - the monitor data area (where the monitor variables are stored)
   </LI>
   <LI>
      <CODE>MCODE</CODE> - the monitor code
   </LI>
</UL>
<p>
<BR>
<b>A little rant:</b>

While it would have been nice to include the UART code as a stub code segment, ZASM's handling of segments makes that impractical. Because the segment name is not referenced anywhere inside the main ROM code, ZASM skips it entirely—<em>but only when building a .hex file</em>. Despite the fact that it builds a BIN just fine, it just happily ignores segment names you don't directly reference in code when producing Intel HEX output.  Essentially, this is yet another entertaining reason why having an assembler with a well-documented, external linker really pays off -- End rant.
</p>
<p>
<BR>
<b>Why ZASM then?</b> 

Well initially its what I know, so that helps but to be honest looking at the way it handles most code I believed on the onset it would be easier to fix the code with the way ZASM handles syntax. While that was true, most of the changes with the exception of the big table for the command processor, the biggest issues came when I tried to use the hex output. In embedded programming its basically essential that the .hex generation of whatever you are using is a carbon copy of the binary output. That's simply not the case. While I’m certain its possible to make that work as intended, there are other assemblers that have better documented linking behavior, such as the 'as' macro assembler (http://john.ccac.rwth-aachen.de:8000/as/). Most likely that would have been the better choice. Maybe I will see if its possible to move that in that direction, the biggest advantage is the well documented linker.  
</p>

<H3>
The Legal bits:
</H3>
<p>
While this does not have a specific license, it is (C) David Dunfield 1996-2007.
please check out the COPY.TXT file, it includes the expectations and guidelines 
for the distribution of the code.
</p>

<br>

<H3>Disclaimer</H3>

<p>
David, nor myself are liable for any use of this software,  it is found to 
function and is "AS-IS".  You certainly are quite welcome to provide feedback and 
fixes in the form of a pull request, but under no circumstances should this 
be considered fit for any purpose, function or production use -- though I have
found it quite useful over the years.
</p>
