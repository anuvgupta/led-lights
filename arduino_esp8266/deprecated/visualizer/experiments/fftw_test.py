import pyfftw
import numpy

numpy.set_printoptions(threshold=numpy.nan)

# input = pyfftw.zeros_aligned(20, dtype='float64', n=16)
amplitude = pyfftw.n_byte_align(numpy.asarray(
    [-2562, -1807, -2337, -1672, -2026, -1522, -1889, -1442, -1834, -1465, -738, -1196,
    -588, -1133, -679, -1032, -501, -924, -499, -969, -438, -1024, -272, -1023,
    -1, -995, 270, -890, 331, -833, 302, -789, 350, -694, 438, -596,
    391, -637, 426, 81, 336, 658, 317, 642, 223, 557, 110, 501,
    -18, 398, 111, 590, -533, 72, -1026, -307, -1202, -486, -1367, -692,
    -1417, -775, -1548, -894, -1509, -967, -1525, -1174, -1471, -1350, -562, -1210,
    -832, -1252, -1010, -1191, -938, -1021, -884, -1013, -974, -1090, -1152, -1176,
    -1226, -1258, -1246, -1341, -1236, -1331, -1183, -1357, -1150, -1411, -1203, -1504,
    -1297, -1767, -935, -1016, -705, -346, -589, -54, -424, 194, -333, 340,
    -191, 377, 165, 647, -575, 108, -817, -93, -725, -65, -567, -107,
    -268, -87, -146, -65, -120, -57, -168, -218, 227, -276, 1265, 2,
    1056, 172, 971, 244, 1002, 359, 988, 351, 977, 430, 986, 507,
    883, 624, 766, 700, 763, 820, 773, 857, 750, 813, 661, 617,
    321, 138, 487, 760, 744, 1105, 781, 998, 689, 854, 564, 756,
    621, 783, 859, 1006, 64, 418, -275, 213, -455, 187, -610, 92,
    -602, 31, -508, -19, -550, -6, -743, -225, -254, -316, 445, -204,
    236, -196, 195, -276, 171, -231, 111, -217, 95, -113, 103, -128,
    102, -77, 86, -120, 66, -52, 52, -47, 101, -6, 378, -7,
    457, -263, 762, 699, 997, 1173, 1150, 1216, 1149, 1312, 1096, 1460,
    1161, 1581, 1091, 1598, 459, 1102, 349, 997, 288, 1063, 227, 1074,
    127, 1096, 208, 1103, 306, 1111, 317, 1015, 1182, 1202, 1497, 1252,
    1225, 1094, 1187, 847, 1059, 691, 902, 530, 777, 485, 677, 342,
    706, 348, 680, 232, 608, 179, 468, 62, 300, -95, 348, -248,
    279, -547, 610, 393, 666, 791, 722, 825, 835, 842, 789, 900,
    900, 1046, 572, 852, -78, 419, -240, 350, -301, 382, -261, 405,
    -254, 470, -201, 404, -291, 270, -445, 7, 532, 46, 609, -94,
    414, -66, 476, 60, 499, 55, 442, 62, 425, 214, 402, 237,
    340, 257, 284, 192, 439, 364, 525, 507, 485, 605, 511, 597,
    459, 384, 1040, 1541, 1342, 1916, 1532, 1905, 1645, 1914, 1741, 1926,
    2221, 2245, 1880, 1975, 1442, 1671, 1306, 1519, 1108, 1351, 970, 1212,
    856, 1052, 672, 818, 400, 570, 385, 256, 1347, 269, 1035, -13,
    716, -230, 558, -360, 429, -524, 449, -579, 458, -529, 328, -599,
    250, -550, 119, -506, -29, -431, -129, -341, -150, -352, -54, -250,
    -44, -310, 345, 620, 453, 848, 589, 723, 645, 523, 634, 510,
    991, 904, 452, 524, -40, 330, -410, 304, -656, 396, -863, 410,
    -999, 283, -1039, 82, -1236, -126, -939, -196, 37, 48, -347, -88,
    -567, -291, -608, -372, -613, -401, -427, -352, -262, -349, -256, -492,
    -186, -485, 15, -378, 130, -360, 186, -393, 326, -413, 478, -346,
    519, -493, 939, 593, 969, 819, 1031, 712, 1291, 808, 1489, 1007,
    1685, 1447, 915, 850, 655, 654, 499, 652, 332, 654, 227, 655,
    115, 584, 139, 626, -2, 571, 491, 513, 1155, 612, 895, 483,
    762, 341, 634, 207, 472, 99, 475, 47, 552, -14, 562, -69,
    413, -153, 259, -171, 161, -109, 149, 28, 69, 19, -75, -95,
    -232, -343, 76, 674, 110, 831, 85, 691, 89, 678, 349, 837,
    619, 1120, -137, 511, -279, 403, -296, 368, -492, 365, -565, 461,
    -526, 432, -485, 368, -591, 224, 453, 379, 928, 549, 916, 569,
    1038, 565, 1153, 594, 1226, 679, 1417, 693, 1520, 734, 1608, 801,
    1672, 780, 1652, 769, 1502, 766, 1484, 850, 1405, 791, 1291, 764,
    1290, 816, 1573, 1841, 1475, 1844, 1370, 1690, 1223, 1620, 1419, 1761,
    1462, 1826, 1042, 1378, 1054, 1432, 1181, 1473, 1267, 1499, 1100, 1561,
    910, 1466, 817, 1435, 635, 1380, 1763, 1650, 1623, 1649, 1379, 1453,
    1264, 1292, 1183, 1178, 1003, 1172, 1040, 1106, 1051, 1057, 1055, 1055,
    1018, 1048, 1183, 1104, 1247, 1135, 1300, 1178, 1301, 1104, 1234, 1027,
    1242, 1095, 1486, 1972, 1497, 1907, 1560, 1888, 1586, 1908, 1884, 2066,
    1398, 1766, 958, 1313, 877, 1141, 866, 1155, 992, 1309, 1152, 1491,
    1209, 1612, 1304, 1703, 1453, 1704, 2680, 2012, 2447, 2098, 2491, 2197,
    2525, 2317, 2547, 2353, 2447, 2350, 2515, 2234, 2485, 2143, 2568, 1999,
    2485, 1928, 2530, 1895, 2543, 1801, 2576, 1772, 2538, 1802, 2438, 1789,
    2313, 1924, 2465, 2844, 2556, 2950, 2592, 3018, 2558, 3030, 2920, 3320,
    2289, 2905, 1944, 2681, 1813, 2520, 1794, 2536, 1750, 2582, 1870, 2611,
    1883, 2533, 1758, 2417, 1929, 2364, 2976, 2573, 2734, 2612, 2855, 2669,
    2803, 2746, 2692, 2731, 2576, 2709, 2647, 2625, 2540, 2530, 2520, 2424,
    2438, 2406, 2463, 2263, 2467, 2062, 2515, 1967, 2320, 1978, 2200, 1915,
    2297, 2227, 2585, 3073, 2643, 3037, 2598, 3125, 2616, 3264, 3078, 3747,
    2405, 3201, 2273, 3055, 2322, 2973, 2494, 3104, 2635, 3116, 2799, 3071,
    2929, 3027, 2953, 2915, 3516, 2901, 4372, 3043, 4096, 2989, 4115, 2916,
    4033, 2966, 3960, 3064, 3810, 3133, 3609, 3014, 3426, 2967, 3468, 3001,
    3495, 3144, 3564, 3243, 3497, 3262, 3536, 3248, 3452, 3261, 3272, 3075,
    3293, 3423, 3444, 4094, 3437, 3914, 3570, 3952, 3729, 4010, 3938, 4290,
    2918, 3570, 2597, 3468, 2473, 3362, 2469, 3429, 2605, 3441, 2715, 3425,
    2727, 3337, 2637, 3094, 3376, 3050, 3568, 3099, 3156, 2992, 3106, 2834,
    3043, 2777, 2971, 2729, 2871, 2610, 2761, 2443, 2669, 2374, 2646, 2260,
    2619, 2243, 2687, 2272, 2738, 2348, 2891, 2397, 3092, 2485, 3151, 2393,
    3435, 2973, 3881, 3708, 4076, 3689, 4139, 3800, 4250, 3902, 4263, 4125,
    3448, 3582, 3210, 3572, 2961, 3446, 2731, 3414, 2683, 3350, 2819, 3360,
    2907, 3430, 2922, 3424, 4153, 3646, 4168, 3731, 3957, 3717, 3964, 3763,
    3924, 3838, 3800, 3931, 3798, 3922, 3880, 3878, 3987, 3912, 3938, 3831,
    3811, 3728, 3785, 3638, 3774, 3596, 3740, 3558, 3800, 3658, 3715, 3417,
    3862, 3941, 4033, 4418, 3964, 4202, 3787, 4260, 3913, 4363, 3648, 4222,
    2994, 3706, 2823, 3628, 2710, 3547, 2624, 3580, 2586, 3530, 2540, 3409,
    2544, 3222, 2672, 3050, 3848, 3097, 3548, 2910, 3359, 2736, 3205, 2611,
    3135, 2432, 3030, 2381, 2991, 2291, 2899, 2285, 2855, 2333, 2749, 2350,
    2772, 2468, 2745, 2519, 2711, 2462, 2708, 2354, 2764, 2407, 2644, 2155,
    2864, 2906, 2991, 3419, 3034, 3308, 2929, 3290, 3139, 3437, 2685, 3089,
    2199, 2685, 2110, 2623, 2170, 2637, 2136, 2694, 2199, 2740, 2214, 2782,
    2309, 2778, 2834, 2845, 4008, 3038, 3732, 2976, 3762, 2948, 3660, 2927,
    3559, 2798, 3541, 2899, 3616, 2932, 3552, 2991, 3565, 3028, 3474, 3004,
    3382, 2957, 3209, 2926, 3149, 3070, 3041, 3157, 2974, 3213, 2790, 2871,
    3140, 3684, 3264, 3960, 3212, 3633, 2958, 3362, 3086, 3408, 2287, 2732,
    1820, 2389, 1638, 2268, 1563, 2186, 1323, 2071, 1115, 1972, 969, 1935,
    752, 1802, 1212, 1751, 2047, 1766, 1816, 1672, 1897, 1631, 1879, 1659,
    1783, 1599, 1685, 1653, 1676, 1594, 1593, 1592, 1643, 1551, 1700, 1518,
    1831, 1482, 1899, 1473, 2037, 1537, 2028, 1502, 2013, 1510, 1943, 1187,
    2445, 2271, 2721, 2622, 2852, 2485, 2769, 2432, 3047, 2628, 2139, 1810,
    1807, 1615, 1561, 1679, 1374, 1741, 1233, 1741, 1091, 1692, 967, 1612,
    725, 1490, 1445, 1635, 1886, 1731, 1800, 1828, 1931, 1982, 2053, 2124,
    2145, 2150, 2182, 2339, 2263, 2375, 2192, 2377, 2154, 2262, 2076, 2174,
    2181, 2210, 2249, 2248, 2239, 2190, 2084, 2053, 1939, 2008, 1609, 1550,
    1640, 2435, 1552, 2341, 1536, 2029, 1514, 1949, 1661, 2075, 710, 1269,
    431, 936, 153, 675, -22, 480, -115, 291, -78, 170, -102, 103,
    -150, -8, 978, 218, 1000, 206, 952, 204, 1013, 274, 1089, 385,
    1157, 358, 1176, 418, 1193, 394, 1137, 366, 1049, 239, 808, 123,
    739, 106, 677, 188, 673, 236, 627, 207, 604, 232, 523, -58,
    861, 1182, 915, 1351, 938, 1283, 1126, 1373, 1094, 1361, 302, 707,
    164, 611, 111, 630, 150, 597, 117, 589, 114, 590, 37, 574,
    164, 562, 1218, 825, 837, 812, 784, 976, 833, 1104, 795, 1084,
    734, 858, 757, 789, 640, 695, 513, 614, 421, 536, 272, 458,
    201, 269, 41, 69, -84, -120, -177, -369, -278, -553, -411, -923,
    54, 177, 159, 133, 175, -27, 522, 36, 306, -291, -331, -790,
    -528, -906, -653, -872, -748, -837, -805, -811, -784, -798, -813, -742,
    -524, -608, 348, -272, 7, -317, -80, -291, -62, -386, 5, -405,
    135, -332, 189, -169, -28, -164, -229, -179, -297, -220, -296, -204,
    -316, -272, -345, -312, -317, -296, -267, -372, -330, -522, -438, -820,
    -76, 260, -169, 193, -190, 225, 252, 740, -198, 423, -727, 74,
    -926, -174, -1045, -295, -1078, -320, -1048, -274, -1043, -347, -1120, -383,
    -654, -326, -95, -155, -277, -165, -320, -115, -421, -219, -428, -230,
    -211, -205, 0, -92, 72, -124, 7, -226, -89, -429, -188, -552,
    -363, -774, -521, -941, -534, -1009, -463, -1050, -441, -1077, -454, -1176,
    -234, -235, -499, -535, -585, -722, -191, -486, -828, -1093, -1051, -1110,
    -1132, -1067, -1201, -1013, -1288, -1095, -1419, -1136, -1327, -1184, -1338, -1133,
    -430, -891, -88, -740, -162, -745, -56, -599, 30, -595, 113, -434,
    228, -334, 221, -258, 145, -185, -13, -134, -160, -252, -127, -199,
    -29, -119, -82, -64, -147, -90, -330, -141, -502, -307, -553, -291,
    -195, 738, -190, 589, -42, 587, 259, 800, -567, 31, -627, -107,
    -743, -203, -818, -181, -775, -180, -818, -139, -839, -273, -926, -359,
    108, -266, -6, -283, 0, -321, 36, -202, 132, -172, 264, -23,
    599, 247, 937, 497, 890, 308, 365, -178, -153, -630, 53, -249,
    637, 383, 764, 577, 411, 232, -140, -235, -342, -428, -397, -277,
    -339, 280, -747, -278, -482, -199, 127, 336, -473, -175, -790, -550,
    -1196, -885, -1317, -789, -1174, -429, -1156, -394, -1357, -770, -1326, -847,
    -210, -718, -553, -743, -662, -746, -801, -616, -774, -582, -878, -568,
    -881, -630, -859, -677, -727, -649, -507, -405, -373, -373, -484, -532,
    -586, -700, -595, -663, -671, -730, -830, -888, -948, -1095, -939, -877,
    -630, -62, -806, -376, -700, -461, -655, -423, -1133, -712, -1268, -828,
    -1222, -850, -1016, -642, -773, -392, -617, -246, -580, -320, -37, -19,
    1194, 407, 1053, 417, 1038, 399, 1011, 456, 1081, 444, 1034, 437,
    795, 117, 418, -267, 454, -414, 617, -292, 755, -159, 518, -179,
    133, -366, -158, -353, -333, -398, -542, -658, -763, -962, -766, -664,
    -506, 82, -549, -88, -447, -10, -1003, -511, -1768, -1150, -2097, -1447,
    -2085, -1506, -2122, -1601, -2185, -1635, -2153, -1604, -2049, -1671, -1462, -1480,
    -920, -1344, -1154, -1394, -1093, -1305, -1069, -1127, -1105, -1102, -1059, -1052,
    -1101, -1085, -1247, -1243, -1296, -1315, -1360, -1453, -1388, -1589, -1568, -1586,
    -1672, -1646, -1855, -1701, -2025, -1845, -2143, -1908, -2182, -1971, -1973, -1481,
    -1620, -761, -1515, -898, -1141, -669, -1579, -1251, -1810, -1528, -1767, -1598,
    -1591, -1661, -1435, -1763, -1346, -1761, -1272, -1742, -1178, -1765, -251, -1453,
    -44, -1250, -320, -1202, -439, -1198, -657, -1284, -770, -1302, -735, -1167,
    -752, -1068, -801, -1082, -750, -979, -615, -951, -727, -1004, -1052, -1137,
    -1379, -1302, -1613, -1375, -1753, -1544, -1890, -1740, -1970, -1960, -1887, -1422,
    -1773, -940, -1833, -1218, -1676, -1092, -2607, -1894, -2922, -2113, -2887, -2157,
    -2798, -2233, -2689, -2368, -2630, -2333, -2678, -2343, -2833, -2535, -1900, -2461,
    -2081, -2552, -2173, -2608, -2114, -2572, -2208, -2560, -2232, -2445, -2243, -2392,
    -2325, -2366, -2412, -2430, -2438, -2395, -2370, -2460, -2324, -2545, -2229, -2651,
    -2331, -2753, -2381, -2690, -2418, -2669, -2557, -2683, -2648, -2820, -2389, -2091,
    -2218, -1559, -2110, -1655, -1857, -1595, -2677, -2427, -2871, -2574, -2989, -2582,
    -3097, -2545, -3048, -2551, -2977, -2640, -3049, -2784, -2990, -2794, -1862, -2552,
    -2172, -2590, -2183, -2577, -2068, -2491, -2060, -2517, -2132, -2504, -2088, -2496,
    -2039, -2443, -2074, -2572, -2134, -2611, -2170, -2733, -2180, -2830, -2053, -2895,
    -2182, -2906, -2323, -2862, -2406, -2937, -2582, -2920, -2738, -3022, -2518, -2124,
    -2490, -1797, -2440, -1926, -2549, -1901, -3352, -2528, -3500, -2647, -3481, -2664,
    -3455, -2690, -3345, -2751, -3288, -2855, -3422, -3024, -3146, -3078, -2203, -2968,
    -2577, -3083, -2722, -3144, -2765, -3138, -2803, -3214, -2978, -3145, -3056, -3079,
    -3186, -3051, -3208, -3188, -3234, -3268, -3230, -3344, -3255, -3338, -3145, -3453,
    -3129, -3521, -3244, -3529, -3316, -3664, -3532, -3735, -3848, -4180, -3752, -3481,
    -3827, -3393, -3649, -3489, -3877, -3696, -4418, -4073, -4481, -4006, -4349, -3868,
    -4283, -3802, -4192, -3788, -4092, -3772, -4103, -3821, -3372, -3664, -2544, -3406,
    -2608, -3256, -2500, -3056, -2555, -2998, -2570, -2980, -2640, -2784, -2681, -2721,
    -2748, -2702, -2744, -2650, -2742, -2471, -2738, -2360, -2734, -2225, -2519, -2278,
    -2382, -2360, -2423, -2356, -2534, -2565, -2708, -2771, -2771, -3103, -2434, -2072,
    -2501, -2081, -2388, -2197, -2948, -2695, -3390, -2957, -3717, -2997, -3969, -3188,
    -4172, -3468, -4205, -3596, -4108, -3595, -4174, -3643, -3410, -3554, -3235, -3603,
    -3390, -3741, -3289, -3791, -3361, -3762, -3151, -3546]
, dtype='float64'), n=16, dtype='float64')
print("amplitude: ")
print(amplitude)
print("")
fftw_obj = pyfftw.builders.fft(amplitude)
fourier = numpy.absolute(fftw_obj(amplitude), dtype='float64')
print("fourier: ")
print(fourier)
print("")
max = 0
for x in fourier:
    if x > max:
        max = x
percentages = numpy.empty(len(fourier), dtype='int32')
for i in range(len(percentages)):
    percentages[i] = 10000 * (fourier[i] / max)
print("percentages: ")
print(percentages)
print("")