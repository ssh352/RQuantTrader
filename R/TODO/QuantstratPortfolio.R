#' Initializes a portfolio object.
#'
#' Constructs and initializes a portfolio object, which is used to contain transactions, positions, and aggregate level values.
#'
#' Initializes a portfolio object, which is constructed from the following:
#' $symbols: the identifier used for each instrument contained in the portfolio. Use \code{ls(Portfolio$symbols)} to get a list of symbols.
#' $symbols$[symbol]$txn: irregular xts object of transactions data
#' $symbols$[symbol]$posPL: regular xts object of positions P&L calculated from transactions
#' $symbols$[symbol]$posPL.ccy: regular xts object of positions P&L converted to portfolio currency
#' $summary: aggregated portfolio values
#'
#' Each symbol has three associated tables.  The first, txn, is the transactions table, an irregular time series that contains information about trades or other position adjustments with the following columns:
#' \itemize{
#' \item Txn.Qty: the quantity, usually in units of contracts, changing hands. Positive values indicate a "buy" transaction; negative values are used to indicate a "sell."
#' \item Txn.Price: the price at which the transaction was made,
#' \item Txn.Fees: the sum total of transaction fees associated with the trade,
#' \item Txn.Value: the notional value of the transaction,
#' \item Avg.Txn.Cost: a calculated value for the average net price paid (received) per contract bought (received),
#' \item Pos.Qty: the resulting position quantity of contracts, calculated as the sum of the current transaction and the prior position,
#' \item Pos.Avg.Cost: the calculated average cost of the resulting position, and
#' \item Realized.PL: any prot or loss realized in the transaction from closing out a prior position
#' }
#'
#' The second, posPL, is a container used to store calculated P&L values from transactions and close prices within an instrument. The data series is, however, a regular time series. Columns of the table include:
#' \itemize{
#' \item Pos.Qty the quantity of the position held in the symbol,
#' \item Pos.Value the notional value of the position,
#' \item Txn.Value the net value of the transactions occuring,
#' \item Txn.Fees the total fees associated with transactions,
#' \item Realized.PL any net prot or loss realized through transactions,
#' \item Unrealized.PL any prot or loss associated with the remaining or open position, and
#' \item Trading.PL the sum of net realized and unrealized prot and loss.
#' }
#'
#' The third, posPL.ccy, is the same as the second but translated into the portfolio currency.
#'
#' For each portfolio, the summary slot contains a table that tracks calculated portfolio information through time. The table contains the following columns, held in a regular xts time series:
#' \itemize{
#' \item Long.Value: The sum of the notional value of all positions held long in the portfolio.
#' \item Short.Value: The sum of the notional value of all positions held short in the portfolio.
#' \item Net.Value: The sum of the notional long and notional short value of the portfolio.
#' \item Gross.Value: The sum of the notional long and absolute value of the notional short value of the portfolio.
#' \item Txn.Fees: The sum of brokerage commissions, exchange and other brokerage fees paid by the portfolio during the period.
#' \item Realized.PL: The sum of net realized prots or losses aggregated from the underlying positions in the portfolio. Gross realized prots can be calculated by adding Txn.Fees, the brokerage commission expenses for the period.
#' \item Unrealized.PL: The sum total increase or decrease in unrealized profits or losses on open positions in the portfolio at the end of the period.
#' \item Net.Trading.PL: Net realized prot or loss plus interest income plus change in unrealized prot or loss across all positions in the portfolio.
#' }
#' TODO: add $account: name of the (one) affiliated account
#
#' Outputs
#' Initialized portfolio structure with a start date and initial positions.
#'
#' @param name A name for the resulting portfolio object
#' @param symbols  A list of instrument identifiers for those instruments contained in the portfolio
#' @param initPosQty Initial position quantity, default is zero
#' @param initDate A date prior to the first close price given, used to contain initial account equity and initial position
#' @param currency ISO currency identifier used to locate the portfolio currency
#' @param \dots any other passthrough parameters
#' @author Peter Carl
#' @export
initPortfolio <- function (name = "default", symbols, initPosQty = 0, initDate = "1950-01-01",
                           currency = "USD", ...) {

  if (exists(paste("portfolio", name, sep = "."), envir = .tradingEnv,
             inherits = TRUE))
    stop("Portfolio ", name, " already exists, use updatePortf() or addPortfInstr() to update it.")


  portfolio = new.env(hash = TRUE)
  portfolio[["symbols"]] = new.env(hash = TRUE)

  if (length(initPosQty) == 1)
    initPosQty = rep(initPosQty, length(symbols))
  if (length(initPosQty) != length(symbols))
    stop("The length of initPosQty is unequal to the number of symbols in the portfolio.")

  for (instrument in symbols) {
    portfolio$symbols[[instrument]] = new.env(hash = TRUE)
    i = match(instrument, symbols)
    portfolio$symbols[[instrument]]$txn = initTxn(initDate = initDate,
                                                  initPosQty = initPosQty[i], ... = ...)
    portfolio$symbols[[instrument]]$posPL = initPosPL(initDate = initDate,
                                                      initPosQty = initPosQty[i], ... = ...)
    portfolio$symbols[[instrument]][[paste("posPL", currency,
                                           sep = ".")]] = portfolio$symbols[[instrument]]$posPL
  }
  portfolio$summary <- initSummary(initDate = initDate)
  class(portfolio) <- c("blotter_portfolio", "portfolio")
  attr(portfolio, "currency") <- currency
  attr(portfolio, "initDate") <- initDate
  assign(paste("portfolio", as.character(name), sep = "."),
         portfolio, envir = .tradingEnv)
  return(name)
}




#' get a portfolio object
#'
#' Get a portfolio object conssting of either a nested list (\code{getPortfolio})
#' or a pointer to the portfolio in the \code{.blotter} environment (\code{.getPortfolio})
#'
#' Portfolios in blotter are stored as a set of nested, hashed, environments.
#'
#' The \code{getPortfolio} function returns a nested list.  If you are unsure, use this function.
#'
#' The \code{.getPortfolio} function returns a pointer to the actual environment.
#' Environments in R are passed by reference, and are not copied by the \code{<-}
#' assignment operator.  Any changes made to the environment returned by
#' \code{.getPortfolio} are global.  You have been warned.
#'
#' @param Portfolio string identifying portfolio
#' @param Dates dates subset, not yet supported
#' @param envir the environment to retrieve the portfolio from, defaults to .blotter
#'
#' @seealso \code{\link{initPortf}}, \code{\link{updatePortf}}
#' @export getPortfolio
getPortfolio <- function (Portfolio, envir = .tradingEnv)
{
  pname <- Portfolio
  if (!grepl("portfolio\\.", pname))
    Portfolio <- suppressWarnings(try(get(paste("portfolio",
                                                pname, sep = "."), envir = envir), silent = TRUE))
  else Portfolio <- suppressWarnings(try(get(pname, envir = envir),
                                         silent = TRUE))
  if (inherits(Portfolio, "try-error"))
    stop("Portfolio ", pname, " not found, use initPortf() to create a new portfolio")
  if (!inherits(Portfolio, "portfolio"))
    stop("Portfolio ", pname, " passed is not the name of a portfolio object.")
  return(Portfolio)
}
