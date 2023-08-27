pragma solidity 0.6.4;

interface IParamSufscriber {
    function updateParam(string calldata key, bytes calldata value) external;
}