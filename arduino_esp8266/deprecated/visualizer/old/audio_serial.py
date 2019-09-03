# imports
from collections import deque
import PyCmdMessenger
import pyaudio
import pyfftw
import numpy
import time
import math
import sys

# main thread
if __name__ == '__main__':
    print("\nAudio Visualizer\n")

    # initialize pyaudio, pyfftw, numpy
    p = pyaudio.PyAudio()
    pyfftw.interfaces.cache.enable()
    numpy.set_printoptions(threshold=numpy.nan)

    # set options
    numrects = -1
    while numrects < 0:
        try:
            numrects = int(input("Number of LEDs: "))
        except ValueError:
            numrects = -1
    rheights = [0] * numrects
    print("")
    split_fourier = ""
    while split_fourier == "":
        try:
            split_fourier = str(input("Split fourier (left, right, full): "))
            if split_fourier != "left" and split_fourier != "right" and split_fourier != "full":
                split_fourier = ""
        except ValueError:
            split_fourier = ""
    print("")

    # choose input device
    print("Select INPUT Device:")
    info = p.get_host_api_info_by_index(0)
    numdevices = info.get('deviceCount')
    for i in range(0, numdevices):
        if (p.get_device_info_by_host_api_device_index(0, i).get('maxInputChannels')) > 0:
            print(i, " - ", p.get_device_info_by_host_api_device_index(0, i).get('name'))
    input_device_id = -1
    while input_device_id < 0 or input_device_id >= numdevices:
        try:
            input_device_id = int(input("ID #: "))
        except ValueError:
            input_device_id = -1
    print("")

    # choose output device
    print("Select OUTPUT Device:")
    info = p.get_host_api_info_by_index(0)
    numdevices = info.get('deviceCount')
    for i in range(0, numdevices):
        if (p.get_device_info_by_host_api_device_index(0, i).get('maxOutputChannels')) > 0:
            print(i, " - ", p.get_device_info_by_host_api_device_index(0, i).get('name'))
    output_device_id = -1
    while output_device_id < 0 or output_device_id >= numdevices:
        try:
            output_device_id = int(input("ID #: "))
        except ValueError:
            output_device_id = -1
    print("")

    # asynchronous audio processing callbacks
    current_in_data = None
    data_queue = deque()
    def callback(in_data, frame_count, time_info, status):
        global current_in_data
        # data_queue.appendleft(in_data)
        current_in_data = in_data
        return (in_data, pyaudio.paContinue)

    # arduino serial connector
    i_mult = 1
    arduino_leds = numrects
    serial_baud = 9600
    serial_port = "/dev/cu.usbmodem144101"
    serial_object = PyCmdMessenger.ArduinoBoard(serial_port, baud_rate=serial_baud)
    serial_commands = [ ["receive_frameL", "i" * int(arduino_leds / 2)], ["receive_frameR", "i" * int(arduino_leds / 2)] ]
    serial_messenger = PyCmdMessenger.CmdMessenger(serial_object, serial_commands)
    serial_ints = [0] * arduino_leds
    def serial_update(rh):
        for i in range(arduino_leds):
            serial_ints[i] = int((100 * rh[i]) * i_mult)
            if serial_ints[i] > 100:
                serial_ints[i] = 100
        siL = serial_ints[: len(serial_ints) // 2]
        siR = serial_ints[len(serial_ints) // 2 :]
        serial_messenger.send("receive_frameL", *siL)
        serial_messenger.send("receive_frameR", *siR)

    # set up closing methods
    def onclose():
        print("quitting")
        # close stream, pyaudio
        stream.stop_stream()
        stream.close()
        p.terminate()

    # main loop
    h_mult = 1.1
    def main_loop():
        if stream.is_active() and data_queue != None:
            # try:
            #     in_data = data_queue.pop()
            # except IndexError:
            #     return
            if (current_in_data == None):
                return
            # calculate fourier transform
            input = numpy.fromstring(current_in_data, dtype='int16')
            amplitude = pyfftw.n_byte_align(numpy.asarray(input, dtype='float64'), n=16, dtype='float64')
            fourier = numpy.absolute(fftw_obj(amplitude), dtype='float64')
            # zero out fourier edges
            # for i in range(10):
            #     fourier[i] = 0
            #     fourier[len(fourier) - (i + 1)] = 0
            fourier = fourier[5:len(fourier) - 5]
            if split_fourier == "left":
                fourier = fourier[: len(fourier) // 2]
            elif split_fourier == "right":
                fourier = fourier[len(fourier) // 2 :]
            # calculate percentages
            max = 1.0
            for x in fourier:
                if x > max:
                    max = x
            percentages = numpy.empty(len(fourier), dtype='float64')
            for i in range(len(percentages)):
                percentages[i] = fourier[i] / max
            # # zero out percentage edges
            # for i in range(10):
            #     percentages[i] = 0
            #     percentages[len(percentages) - (i + 1)] = 0
            # modify depth of percentage transform to custom rectangle depth by averaging segments
            depth = len(percentages)
            step = math.ceil(float(depth) / float(numrects))
            moddepth = numrects * step
            if (moddepth > depth):
                percentages = numpy.append(percentages, numpy.zeros(moddepth - depth, dtype='float64'))
            i = 0
            r = 0
            while i < moddepth:
                avg = 0.0
                for j in range(step):
                    avg += percentages[i + j]
                avg /= step
                rheights[r] = avg * h_mult
                i += step
                r += 1
            serial_update(rheights)

    # set up and open stream
    stream = p.open(format=p.get_format_from_width(2),
                    channels=int(p.get_device_info_by_host_api_device_index(0, input_device_id).get('maxInputChannels')),
                    rate=int(p.get_device_info_by_host_api_device_index(0, input_device_id).get('defaultSampleRate')),
                    input=True,
                    output=True,
                    input_device_index=input_device_id,
                    output_device_index=output_device_id,
                    stream_callback=callback)
    stream.start_stream()

    # fftw setup
    amplitude = pyfftw.n_byte_align(numpy.zeros(2048, dtype='float64'), n=16, dtype='float64')
    fftw_obj = pyfftw.builders.fft(amplitude)

    # run main loop
    refresh_rate = 0.1
    while True:
        main_loop()
        time.sleep(refresh_rate)
