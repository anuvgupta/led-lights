import matplotlib.pyplot as plt
from collections import deque
import pyaudio
import pyfftw
import struct
import numpy
import time

# globals
input_device_id = 3
output_device_id = 1
chunk_size = 1024 * 4
data_queue = deque()

# initialize pyaudio, pyfftw, numpy
pa = pyaudio.PyAudio()
pyfftw.interfaces.cache.enable()
numpy.set_printoptions(threshold=numpy.nan)

# asynchronous audio processing callback
def callback(in_data, frame_count, time_info, status):
    data_queue.appendleft(in_data)
    return (in_data, pyaudio.paContinue)

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
amplitude = pyfftw.n_byte_align(numpy.zeros(2 * chunk_size, dtype='float64'), n=16, dtype='float64')
fftw_obj = pyfftw.builders.fft(amplitude)

# matlab setup
fig, ax = plt.subplots()
x = numpy.arange(0, 2 * chunk_size, 2)
line, = ax.plot(x, numpy.random.rand(chunk_size))
ax.set_ylim(0, 255)
ax.set_xlim(0, )

# main loop
while stream.is_active():
    try:
        in_data = data_queue.pop()
    except IndexError:
        continue
    # calculate fourier transform
    input = struct.unpack(str(2 * chunk_size) + "B", in_data)
    # input = pyfftw.n_byte_align(numpy.asarray(input), n=16, dtype='float64')
    data_int = numpy.array(input, dtype='b')[::2] + 127
    line.set_ydata(data_int)
    fig.canvas.draw()
    fig.canvas.flush_events()
    plt.pause(0.00000000001)
plt.show()

print("quitting")
stream.stop_stream()
stream.close()
pa.terminate()
