pragma solidity ^0.4.0;

// provide secure access to the contract
contract CallerOnly {
  address private _owner;

  function CallerOnly(){
    _owner = msg.sender;
  }

  modifier callerOnly(){
    if(msg.sender != _owner){
      throw;
    }
    _;
  }
}

// contract designed to provide easy interface to iata approved agencies and airlines
contract AirlineApproval is CallerOnly {
  mapping (address => bool) listOfAirlines;
  mapping (address => bool) listOfTA;

  function addAirline(address airline) callerOnly {
    listOfAirlines[airline] = true;
  }

  function removeAirline(address airline) callerOnly {
    listOfAirlines[airline] = false;
  }
  
  function addTA(address agency) callerOnly {
    listOfTA[agency] = true;
  }

  function removeTA(address agency) callerOnly {
    listOfTA[agency] = false;
  }

  function isTrustworthAirline(address airline) constant returns (bool) {
    return listOfAirlines[airline];
  }
  
  function isTrustworthTA(address agency) constant returns (bool) {
    return listOfTA[agency];
  }
}

// This contract should only be issued by IATA.
contract Factory {
    address validationBaseAddr;
    mapping (address => address[]) agencyToOrders;
    
    function Factory(address validationBase) {
        validationBaseAddr = validationBase;
    }
    
    function createUniOrder()  {
        if(AirlineApproval(validationBaseAddr).isTrustworthTA(msg.sender)) {
            agencyToOrders[msg.sender].push(new UniOrder(validationBaseAddr, msg.sender));
        }
    }
    
    function getLastContractId(address agency) constant returns (uint) {
        return agencyToOrders[agency].length-1;
    }
}

//This simple contract contains information about traveler
contract Profile {
    bytes32 name;
    bytes32 email;
    bytes32 facebook;
    bytes32 creditCard;
    
    function Profile(
            bytes32 personName,
            bytes32 personMail,
            bytes32 personFacebook,
            bytes32 personCard
    ) {
        name = personName;
        email = personMail;
        facebook = personFacebook;
        creditCard = personCard;
    }
    
    function getName() constant returns (bytes32) {
        return name;
    }
    
    function getEMail() constant returns (bytes32) {
        return email;
    }
    
    function getFacebook() constant returns (bytes32) {
        return facebook;
    }
    
    function getCreditCard() constant returns (bytes32) {
        return creditCard;
    }
}

// Created by agency and should be signed by airline
contract UniOrder{
    address tagency;
    address[] flightDestinations;
    address travelerProfile;
    address validationBaseAddr;
    
    function UniOrder(address validation, address agency) {
        validationBaseAddr = validation;
        tagency = agency;
    }
    
    modifier asAgency(){
        if(msg.sender != tagency){
            throw;
        }
        
        _;
    }
    
    function setUserProfile(address profile) asAgency {
        travelerProfile = profile;
    }
    
    function getUserProfile() constant returns (address) {
        return travelerProfile;
    }
    
    //Easy way of registering new flight
    function addFlightDestination(address airline) asAgency {
        if(AirlineApproval(validationBaseAddr).isTrustworthAirline(airline)) {
            flightDestinations.push(new Flight(tagency, airline));
        } else {
            throw; //Contract will throw exception if airline is not approved
        }
    }
    
    //More complex way which involves already prepared contract based on Flight contract
    function addExistingFlightDestination(address flightContract) asAgency {
        address contractAirline = Flight(flightContract).getAirline();
        address travelAgency = Flight(flightContract).getAgency();
        
        if(AirlineApproval(validationBaseAddr).isTrustworthAirline(contractAirline)
        && tagency == travelAgency) {
            flightDestinations.push(flightContract);
        } else {
            //Exception will be thrown if agency got from flight contract doesnt match current contract one
            //or airline is not approved
            throw;
        }
    }
    
    //Get last registered flight destination
    function getLastFlightDestinationId() constant returns (uint) {
        //-1 means there is not flight destinations
        return flightDestinations.length - 1;    
    }
    
    function getFlightDestination(uint id) constant returns (address) {
        if(id >= 0 && id <= getLastFlightDestinationId()) {
            return flightDestinations[id];
        }
        
        //Throw an exception in case that there are not flight destinations presented
        throw;
    }
    
    function claimRefund() {
        //At this moment it does nothing
    }
}

//Flight contract contains basic information about flight
contract Flight is CallerOnly {
    address tagency;
    address airline;
    address caller;
    bytes32 destination;
    
    function Flight(address agency, address airlineAddr) {
        tagency = agency;
        airline = airlineAddr;
        caller = msg.sender;
    }
    
    modifier asAgency(){
        if(msg.sender != tagency){
            throw;
        }
        
        _;
    }
    
    function setDestination(bytes32 dest) asAgency {
        destination = dest;
    }
    
    function getDestination() constant returns (bytes32) {
        return destination;
    }
    
    function getAirline() constant returns (address) {
        return airline;
    }
    
    function getAgency() constant returns (address) {
        return tagency;
    }
}


//Example of extended flight contract, it can have different insides
//Service codes should be provided by airlines.
contract ExtendedFlight is Flight {
    bytes32[] services;
    
    function addServiceByCode(bytes32 code) asAgency {
        services.push(code);
    }
    
    function getLastServiceId() constant returns (uint) {
        return services.length - 1;
    }
    
    function getServiceById(uint id) constant returns (bytes32) {
        if(id >= 0 && id <= getLastServiceId()) {
            return services[id];
        }
        
        //Throw an exception is case that there are not additional services presented
        throw;
    }
}