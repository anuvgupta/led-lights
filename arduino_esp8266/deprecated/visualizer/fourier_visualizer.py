# imports
from collections import deque
import pyaudio
import pyfftw
import struct
import numpy
import time
import math
import sys
# graphics
import kivy
kivy.require('1.0.6')
from kivy.app import App
from kivy.uix.widget import Widget
from kivy.graphics import Color, Rectangle
from kivy.core.window import Window
from kivy.clock import Clock

# graphics globals
refresh_rate = 0.00000001
w = 1034
h = 400
cw = w * 2
ch = h * 2
xpadding = 10
ypadding = 10
rcolor = (1, 1, 1, 1)
hmult = 1
numrects = -1
rwidth = (cw - (xpadding * 2)) / numrects
rheight = ch - (ypadding * 2)
rheights = [0] * numrects
rectangles = [0] * numrects

# set up window
class AV_Canvas(Widget):
    def __init__(self, **kwargs):
        super(AV_Canvas, self).__init__(**kwargs)
        self.size = (cw * 2, ch * 2)
        self.pos = (0, 0)
        with self.canvas.before:
            Color(0.1, 0.1, 0.1, 1)
            self.rect = Rectangle(size=self.size, pos=self.pos)
        with self.canvas:
            Color(rcolor)
            for r in range(numrects):
                rectangles[r] = Rectangle(size=(rwidth, rheight), pos=(xpadding + (rwidth * r), ypadding))
    def update(self):
        for r in range(numrects):
            newh = rheights[r] * rheight * hmult
            rectangles[r].size = (rwidth, newh)
            rectangles[r].pos = (xpadding + (rwidth * r), (ch - ypadding * 2 - newh) / 2)
class AV_GUI(App):
    title = "Audio Visualizer"
    canvas = None
    def build(self):
        self.canvas = AV_Canvas()
        Clock.schedule_interval(main_loop, refresh_rate)
        return self.canvas
    def update(self):
        if self.canvas:
            self.canvas.update()
    def on_stop(self):
        onclose()

# main thread
if __name__ == '__main__':
    print("\nAudio Visualizer\n")

    # globals
    input_device_id = 3
    output_device_id = 1
    chunk_size = 1024 * 4
    data_queue = deque()

    # initialize pyaudio, pyfftw, numpy
    pa = pyaudio.PyAudio()
    pyfftw.interfaces.cache.enable()
    numpy.set_printoptions(threshold=numpy.nan)

    # set options
    numrects = -1
    while numrects < 0:
        try:
            numrects = int(input("Order of depth: "))
        except ValueError:
            numrects = -1
    numrects = int(math.pow(2, numrects))
    rwidth = (cw - (xpadding * 2)) / numrects
    rheight = ch - (ypadding * 2)
    rheights = [0] * numrects
    rectangles = [0] * numrects
    print("rwidth: " + str(rwidth))
    print("")

    # choose input device
    print("Select INPUT Device:")
    info = pa.get_host_api_info_by_index(0)
    numdevices = info.get('deviceCount')
    for i in range(0, numdevices):
        if (pa.get_device_info_by_host_api_device_index(0, i).get('maxInputChannels')) > 0:
            print(i, " - ", pa.get_device_info_by_host_api_device_index(0, i).get('name'))
    input_device_id = -1
    while input_device_id < 0 or input_device_id >= numdevices:
        try:
            input_device_id = int(input("ID #: "))
        except ValueError:
            input_device_id = -1
    print("")

    # choose output device
    print("Select OUTPUT Device:")
    info = pa.get_host_api_info_by_index(0)
    numdevices = info.get('deviceCount')
    for i in range(0, numdevices):
        if (pa.get_device_info_by_host_api_device_index(0, i).get('maxOutputChannels')) > 0:
            print(i, " - ", pa.get_device_info_by_host_api_device_index(0, i).get('name'))
    output_device_id = -1
    while output_device_id < 0 or output_device_id >= numdevices:
        try:
            output_device_id = int(input("ID #: "))
        except ValueError:
            output_device_id = -1
    print("")

    # asynchronous audio processing callback
    def callback(in_data, frame_count, time_info, status):
        data_queue.appendleft(in_data)
        return (in_data, pyaudio.paContinue)

    # set up closing method
    def onclose():
        print("quitting")
        # close stream, pyaudio
        stream.stop_stream()
        stream.close()
        pa.terminate()

    # main loop
    def main_loop(self):
        if stream.is_active() and data_queue != None:
            try:
                in_data = data_queue.pop()
            except IndexError:
                return
            # calculate fourier transform
            input = struct.unpack(str(2 * chunk_size) + "B", in_data)
            # input = (numpy.array(input, dtype='b')[::2] + 128)
            input = (numpy.array(input, dtype='b')[::2] - 128)
            input = pyfftw.n_byte_align(input, n=16, dtype='float64')
            fourier = numpy.absolute(fftw_obj(input), dtype='float64')
            fourier = fourier[0 : len(fourier) // 2]
            # zero out fourier edges
            for i in range(5):
                fourier[i] = 0
                fourier = fourier[:len(fourier) - i - 1]
            scaled_fourier = fourier
            # calculate percentages
            max = scaled_fourier.max()
            if max == 0:
                max = 1
            percentages = numpy.empty(len(scaled_fourier), dtype='float64')
            for i in range(len(percentages)):
                percentages[i] = scaled_fourier[i] / max
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
                rheights[r] = avg
                i += step
                r += 1
            # for r in range(numrects):
            #     rheights[r] = percentages[r]

            # when taking averages, average one more value each time (increment step each time)

            gui.update()

    # set up and open stream
    stream_channels = int(pa.get_device_info_by_host_api_device_index(0, input_device_id).get('maxInputChannels'))
    stream_rate = int(pa.get_device_info_by_host_api_device_index(0, input_device_id).get('defaultSampleRate'))
    stream = pa.open(format=pa.get_format_from_width(2),
                    channels=stream_channels,
                    rate=stream_rate,
                    input=True,
                    output=True,
                    input_device_index=input_device_id,
                    output_device_index=output_device_id,
                    stream_callback=callback,
                    frames_per_buffer=int(chunk_size / stream_channels))
    stream.start_stream()

    # fftw setup
    amplitude = pyfftw.n_byte_align(numpy.zeros(chunk_size, dtype='float64'), n=16, dtype='float64')
    fftw_obj = pyfftw.builders.fft(amplitude)

    # display window
    Window.size = (w, h)
    gui = AV_GUI()
    gui.run()
