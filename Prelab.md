# Prelab Answers

## Part 1: Zybo Z7-20 Reference Manual — Audio Codec

**Q1. Is the audio codec integrated into our Zynq SoC?**
No. The SSM2603 is a separate IC located on the back of the board. The manual states its digital interface "is wired to the programmable logic side of the Zynq" — meaning it's an external chip connected via pins, not integrated silicon.

**Q2. MPN of the audio codec?**
SSM2603 (Analog Devices)

**Q3. Protocol for audio data transfer?**
**I²S** (Inter-IC Sound)

**Q4. Protocol for configuration?**
**I2C** (2-wire serial interface)

**Q5. Device address of the SSM2603?**
`0011010b` (7-bit, binary). This corresponds to 0x1A hex. Note: the CSB pin on the SSM2603 is tied low on the Zybo, selecting this address.

**Q6. Digital I/O voltage level?**
**3.3 V.** All I²S and I2C signals such as BCLK, PBDAT, PBLRC swing between 0 V and 3.3 V.

**Q7. Default sampling rate?**
**48 kHz**

**Q8. Required master clock for the default sampling rate?**
**12.288 MHz**

**Q9. Do we need an ODDR primitive to forward the clock off the Zynq?**
**Yes.** If we route a clock through the normal fabric to an output, it travels the slow, asymmetric routing fabric rather than the dedicated clock spine causing jitter and skew.

---

## Part 2: SSM2603 Datasheet

**Q1. What does the IC do?**
The SSM2603 is a stereo audio codec. It contains:
- An **ADC path**: analog audio in (line-in or mic) → anti-aliasing filter → ADC → digital output (RECDAT)
- A **DAC path**: digital input (PBDAT) → DAC → reconstruction filter → analog audio out (headphone/line)
- A **control interface** (I2C via SDIN/SCLK) to configure internal muxes, amplifiers, and digital settings
- A **clock generator** driven by MCLK to produce BCLK and LRC clocks

**Q2. MCLK/XTI**
The master clock input. This is the reference clock that drives all internal timing. The codec derives BCLK, RECLRC, and PBLRC from this clock using fixed dividers. It can accept either an external oscillator clock or be connected to a crystal.

**Q3. BCLK**
The bit clock for the digital audio serial interface. Each rising/falling edge clocks one bit of audio data in or out. In slave mode it is an **input** driven by the Zynq; in master mode it's an output.

**Q4. PBDAT**
Playback data input. This is the serial data line where the FPGA shifts in audio samples for the DAC to convert to analog. Left and right channel data are time multiplexed on this single pin.

**Q5. PBLRC**
Playback Left/Right Clock (word select). It runs at the sampling frequency Fs and tells the codec which channel (low = left; high = right) is currently being clocked in on PBDAT. Also acts as the frame sync signal.

**Q6. RECDAT**
Record data output. The ADC shifts digitized audio samples out on this pin, time-multiplexed for left and right channels, for the FPGA to read.

**Q7. RECLRC**
Record Left/Right Clock. Same function as PBLRC but for the record (ADC) path — it runs at Fs and indicates which channel is currently valid on RECDAT.

**Q8. MUTE**
DAC output mute, **active low**. When driven low (or left floating, since there's a pull-down resistor on the Zybo), the analog outputs are silenced.

**Q9. SDIN**
I2C data line for the software control interface. Used to write configuration registers (e.g., set gain, select audio path, set format). Bidirectional.

**Q10. SCLK**
I2C clock input for the software control interface. Clocks the serial control data in/out on SDIN.

---

**Q11. Default digital audio input format (Register R7, FORMAT[1:0])?**
`10` = **I2S mode** (hardware default)

**Q12. Default data word length (Register R7, WL[1:0])?**
`10` = **24 bits** (hardware default)

---

**Q13. Which figure corresponds to the default input mode?**
**Figure 25 — I2S Audio Input Mode** (since FORMAT defaults to `10` = I2S)

**Q14. How do we know which audio channel a sample belongs to?**
By the state of **RECLRC/PBLRC**. When the LRC clock is **low**, the current data is the **left channel**; when **high**, it is the **right channel**.

**Q15. Which channel is transmitted first? Does it matter?**
The **left channel** is transmitted first (LRC goes low first). Yes, it matters, both transmitter and receiver must agree on which LRC polarity corresponds to which channel, otherwise left and right audio will be swapped.

**Q16. Relationship between RECLRC/PBLRC and Fs?**
RECLRC/PBLRC **= Fs**. The LRC clock toggles once per channel, so its period = 1/Fs (one full LRC cycle spans one left + one right sample).

**Q17. When does data start shifting? Best signal for FSM next-state logic?**
In I2S mode there is a **one BCLK cycle delay** after LRC changes state before the MSB appears on the data line. The most useful signal for next-state logic is the **falling edge of RECLRC/PBLRC** — it's the event that triggers the start of a new frame, giving you one full BCLK cycle to prepare before the first data bit arrives.

**Q18. When is data shifted out? Which edge?**
Data is driven/changed on the **falling edge of BCLK**.

**Q19. When is data shifted in (sampled)? Which edge?**
Data is sampled (read) on the **rising edge of BCLK**.

**Q20. What does X mean?**
**Don't Care** — those bit positions are undefined/unused and should be ignored by the receiver.

**Q21. Which direction is data shifted?**
**MSB first** — the datasheet states: "All modes are MSB first."

**Q22. Advantage of sampling and shifting 180° out-of-phase; why 50% duty cycle helps?**
Changing data on the falling edge and sampling on the rising edge maximizes both setup time and hold time simultaneously — each gets half a BCLK period of margin. A 50% duty cycle means the setup window and hold window are equal (and maximum), giving symmetric, robust timing margins for both the transmitter and receiver. If the duty cycle were skewed, one margin would shrink, making the interface more susceptible to timing violations.

---

## Table 30 Questions (Normal Mode, CLKDIV2 = 0)

**Q21 (Table 30). BCLK as a function of MCLK periods?**
At 48 kHz with 12.288 MHz MCLK:
- 12.288 MHz / 48 kHz = **256 MCLK cycles per sample period**
- Standard BCLK = 64 × Fs = 3.072 MHz (32 bits/channel × 2 channels × 48 kHz)
- **MCLK / BCLK = 12.288 / 3.072 = 4**
- So **1 BCLK period = 4 MCLK periods**

**Q22 (Table 30). Scaling factor between MCLK and Fs?**
12.288 MHz / 48 kHz = **256**. One sample period Ts = 256 MCLK periods (equivalently, MCLK = 256 × Fs).

**Q23 (Table 30). How many BCLK cycles per sampling period Ts? Why?**
**64 BCLK cycles** per Ts. There are 2 channels × 32 BCLK cycles per channel = 64. Each channel gets 32 BCLK slots (1 X delay + 24 data bits + 7 padding bits), which divides evenly into the 256 MCLK period frame (256/4 = 64).

**Q24 (Table 30). How many BCLK cycles before LRC changes state?**
**32 BCLK cycles**. Each half-frame (one channel) = 1 X + 24 data bits + 7 padding = 32 BCLK cycles. After 32 clocks, LRC toggles to the next channel.

**Q25. Summarize how I2S works:**
I2S is a 3-wire synchronous serial protocol (BCLK, LRC, DATA). BCLK ticks at 64× the sample rate. LRC toggles at the sample rate Fs to indicate which channel (left when low, right when high). One BCLK cycle after LRC changes, the MSB of that channel's sample is placed on the data line. Each subsequent BCLK cycle shifts the next bit, MSB→LSB, until all 24 bits (plus padding) are transmitted. The transmitter changes data on BCLK falling edges; the receiver samples on rising edges. This repeats every 1/Fs seconds, alternating between left and right channels.

**Q26. Does the Zybo reference manual timing diagram match the SSM2603 datasheet?**
The Zybo manual's timing diagram does **not exactly match** any SSM2603 datasheet figure — it appears to show a generic I2S waveform that omits the one-cycle delay present in Figure 25. The **SSM2603 datasheet is more trustworthy** for implementation purposes. The Zybo manual is a board-level reference that delegates specifics to the IC datasheet; the IC datasheet is the authoritative specification for how the chip actually behaves. Always design to the IC datasheet timing.
