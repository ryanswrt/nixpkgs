{ lib, python3, fetchPypi, dvc }:

python3.pkgs.buildPythonPackage rec {
  pname = "dvc-gs";
  version = "2.21.0";
  format = "setuptools";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-MGNDEhJJGSQIPDXGv/y4u1UHnh4HnNbKtQbGHys0dSA=";
  };

  nativeBuildInputs = with python3.pkgs; [ setuptools-scm ];

  propagatedBuildInputs = with python3.pkgs; [ gcsfs dvc ];

  # relatively sure cloud access is needed for tests
  doCheck = false;

  meta = with lib; {
    description = "gs plugin for dvc";
    homepage = "https://pypi.org/project/dvc-gs/2.21.0";
    license = licenses.asl20;
    maintainers = with maintainers; [ ];
  };
}
