pragma solidity 0.6.4;

interface IFSCValidatorSet {
  function misdemeanor(address validator) external;
  function felony(address validator)external;
  function isCurrentValidator(address validator) external view returns (bool);
}
