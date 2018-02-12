#!/usr/bin/env bash
set -e

if [ -z ${XGB_VERSION} ]; then
    echo "XGB_VERSION must be set"
    exit 1
fi

OUTDIR="target/h2o"
JAR_FILE="xgboost4j/target/xgboost4j-${XGB_VERSION}.jar"
JAR_FILENAME=$(basename "$JAR_FILE")
OS=$(uname | sed -e 's/Darwin/osx/' | tr '[:upper:]' '[:lower:]')
BITS=$(getconf LONG_BIT)
PLATFORM="${OS}_${BITS}"
LIB_SUFFIX=

if [ -n "${USE_GPU}" ]; then
    LIB_SUFFIX="${LIB_SUFFIX}_gpu"
elif [ -n "${USE_OMP}" ]; then
    LIB_SUFFIX="${LIB_SUFFIX}_omp"
else
    LIB_SUFFIX="${LIB_SUFFIX}_minimal"
fi

cat <<EOF
===========
  This script builds libraries for H2O integration

  DO NOT FORGET TO SETUP CXX and CC ENV VARS!
      CXX=${CXX}
      CC=${CC}
      PLATFORM=${PLATFORM}
      USE_GPU=${USE_GPU}
      USE_OMP=${USE_OMP}
      XGB_VERSION=${XGB_VERSION}

===========

EOF

# Build only basic package
echo "Building package...."
mvn -Dmaven.test.skip=true -DskipTests clean package -pl xgboost4j -am > build-log-$(date +%s).log

# Create output
rm -rf "${OUTDIR}"
mkdir -p "${OUTDIR}"

# Copy jar file
cp "${JAR_FILE}" "${OUTDIR}"

# Extract library
(
cd  $OUTDIR
jar -xf "$JAR_FILENAME" lib
# Remove lib from jar file
echo "Removing native libs from jar file..."
zip -d "$JAR_FILENAME" lib/ 'lib/*'

# Put library into actual place
echo "Generating jar file with native libs..."
mkdir "lib/${PLATFORM}"
find lib -type f | while read -r f; do
    fname=$(basename "$f")
    fname=${fname//./$LIB_SUFFIX.}
    mv "$f" "lib/${PLATFORM}/$fname"
done
native_lib_jar=${JAR_FILENAME//-/-native-${OS}-}
jar -cf "${native_lib_jar}" ./lib
rm -rf ./lib
)


cat <<EOF

==========
  Please see output in "$(pwd)/target" folder.

$(find "${OUTDIR}" -type f)
==========

EOF