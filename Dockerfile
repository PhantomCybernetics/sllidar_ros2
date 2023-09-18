ARG ROS_DISTRO=humble
ARG PREFIX=

FROM ros:$ROS_DISTRO

RUN apt upgrade -y

RUN apt-get update -y --fix-missing
RUN apt-get install -y vim mc git
RUN apt install -y libgpiod-dev
RUN apt install -y wget

WORKDIR /root/
RUN wget https://github.com/joan2937/pigpio/archive/master.zip
RUN unzip master.zip
RUN cd pigpio-master
RUN make
RUn sudo make install

# select bash as default shell
#SHELL ["/bin/bash", "-c"]

# generate entrypoint script
RUN echo '#!/bin/bash \n \
set -e \n \
\n \
# setup ros environment \n \
source "/opt/ros/'$ROS_DISTRO'/setup.bash" \n \
test -f "/ros2_ws/install/setup.bash" && source "/ros2_ws/install/setup.bash" \n \
\n \
exec "$@"' > /ros_entrypoint.sh

RUN chmod a+x /ros_entrypoint.sh

# source underlay on every login
RUN echo 'source /opt/ros/'$ROS_DISTRO'/setup.bash' >> /root/.bashrc
RUN echo 'test -f "/ros2_ws/install/setup.bash" && source "/ros2_ws/install/setup.bash"' >> /root/.bashrc

WORKDIR /ros2_ws
RUN mkdir -p $ROS_WS/src

# install everything needed
# RUN git clone https://github.com/husarion/sllidar_ros2.git /ros2_ws/src/sllidar_ros2 -b main && \
RUN --mount=type=bind,source=./sllidar_ros2,target=/ros2_ws/src/sllidar_ros2 \
    . /opt/ros/$ROS_DISTRO/setup.sh && \
    rosdep update --rosdistro $ROS_DISTRO && \
    rosdep install --from-paths src --ignore-src -y && \
    colcon build --symlink-install --event-handlers console_direct+

# PY tests
RUN apt-get install -y pip
RUN pip install RPi.GPIO

# select bash as default shell
#iSHELL ["/bin/bash", "-c"]

#COPY healthcheck.py /
#COPY run_healthcheck.sh /

RUN echo $(cat /ros2_ws/src/sllidar_ros2/package.xml | grep '<version>' | sed -r 's/.*<version>([0-9]+.[0-9]+.[0-9]+)<\/version>/\1/g') > /version.txt

#HEALTHCHECK --interval=10s --timeout=10s --start-period=5s --retries=6  \
#    CMD /run_healthcheck.sh

# Without this line LIDAR doesn't stop spinning on container shutdown. Default is SIGTERM.
STOPSIGNAL SIGINT

ENTRYPOINT ["/ros_entrypoint.sh"]
CMD [ "bash" ]
