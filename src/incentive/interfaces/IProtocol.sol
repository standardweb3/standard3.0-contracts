interface IProtocol {
    function feeOf(address base, address quote, address account, bool isMaker) external view returns (uint32 feeNum);

    function isSubscribed(address account) external view returns (bool isSubscribed);

    function terminalName(address terminal) external view returns (string memory terminalName);
}
