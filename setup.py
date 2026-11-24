import os

from setuptools import find_namespace_packages, setup

os.chdir(os.path.normpath(os.path.join(os.path.abspath(__file__), os.pardir)))

setup(
    packages=find_namespace_packages(),
    include_package_data=True,
)
