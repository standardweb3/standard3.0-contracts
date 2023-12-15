

interface IBond {
    function initialize(
        uint256 id_,
        address collateral_,
        address debt_,
        address market_
    ) external;
}