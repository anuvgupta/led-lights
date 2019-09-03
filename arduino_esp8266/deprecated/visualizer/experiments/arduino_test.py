import PyCmdMessenger
import numpy
import time

num = 18  # must be even
arduino = PyCmdMessenger.ArduinoBoard("/dev/cu.usbmodem144101", baud_rate=9600)
commands = [ ["receive_frameL", "i" * int(num / 2)], ["receive_frameR", "i" * int(num / 2)] ]
c = PyCmdMessenger.CmdMessenger(arduino, commands)

def getRandPercentages(n):
    data = numpy.random.rand(n).tolist()
    for i in range(n):
        data[i]  = int(data[i] * 100)
    return data

while True:
    p = getRandPercentages(num)
    # print(p)
    pL = p[: len(p) // 2]
    pR = p[len(p) // 2 :]
    print(pR)
    c.send("receive_frameL", *pL)
    c.send("receive_frameR", *pR)
    time.sleep(0.1)
