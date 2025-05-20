{ pkgs, ... }:

{
  # Python development environment
  home.packages = with pkgs; [
    # Core Python packages with all needed libraries
    (python3.withPackages (ps:
      with ps; [
        # Core
        pip
        virtualenv
        setuptools

        # Data science and development libraries
        numpy
        pandas
        matplotlib
        requests
        pyperclip # Clipboard operations

        # GUI development
        tkinter

        # Development tools
        pytest
        black
        flake8
        mypy
        isort
        autopep8
      ]))
    tk # Tk libraries

    # Development environment utilities
    pipenv # For project management
    poetry # Modern Python packaging
  ];
}
