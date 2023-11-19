/**
* Name: FestivalModel
* Based on the internal empty template. 
* Author: roussos, farmaki
* Tags: 
*/


model FestivalModel

global {
	int numberOfPeople <- 1;
	int numberOfFoodStores <- 3;
	int numberOfDrinkStores <- 3;
	int numberOfCenters <- 1;
	int numberOfSecurity <- 1;
	list<FestivalStore> FoodStores;
	list<FestivalStore> DrinkStores;
	
	// All the statements under this init scope will be computed once, at the begining of our simulation. 
	init {
		create FestivalGuest number:numberOfPeople;
		create FestivalStore number:numberOfFoodStores with:(hasFood:true,hasDrinks:false);
		create FestivalStore number:numberOfDrinkStores with:(hasFood:false,hasDrinks:true);
		create InformationCenter number:numberOfCenters with:(targetPoint:{10,10,10});
		
		create SecurityGuard number:1;
		
		create AuctionHouse number:1 with: (id:1) ;
		create AuctionHouse number:1 with: (id:2) ;
		
		FoodStores<-[];
		DrinkStores<-[];
		
		loop counter from: 1 to: numberOfFoodStores + numberOfDrinkStores{
	        FestivalStore store <- FestivalStore[counter - 1];
	        if (store.hasFood=true){
	        	FoodStores<-FoodStores+store;
	        }else if (store.hasDrinks=true){
	        	DrinkStores<-DrinkStores+store;
	        }
	        	
		}
		
	}	
}

species FestivalGuest skills:[moving, fipa]
{	bool isHungry;
	bool isThirsty;
	bool isBad;
	point lastLocation;
	float totalDistance <- 0.0;
	int numOfIterations <-2000;
	list<FestivalStore> visitedFoodStores;
	list<FestivalStore> visitedDrinkStores;
	int wallet;
	
	init{
		lastLocation<-location;
		isHungry <- false;
		isThirsty <- false;
		isBad<-false;
		visitedFoodStores <- [];
		visitedDrinkStores <- [];
		wallet <- 100 * rnd(numberOfPeople);
	}

	string headedTo<-nil;
	
	point targetPoint <- nil;

	reflex print{
		numOfIterations<-numOfIterations-1;
		if (numOfIterations=0){
			write totalDistance;
		}
	}
	
	
	reflex beIdle when: targetPoint = nil
	{
		do wander;
	}
	
	reflex goToTarget when: isHungry=true or isThirsty=true
	{
		if flip(0.2) or (isThirsty and visitedDrinkStores = [] ) or ( isHungry and visitedFoodStores = [] ){
			if(headedTo= nil){
				ask InformationCenter{			
					myself.targetPoint<-self.location;
					myself.headedTo<-"InfoCenter";
				}
			}
		}
		else if (headedTo != "InfoCenter"){
			if isHungry=true and headedTo=nil{
				targetPoint<-visitedFoodStores[rnd(length(visitedFoodStores)-1)].location;
				headedTo<-"FoodStore";
			}
			else if isThirsty=true and headedTo=nil{
				targetPoint<-visitedDrinkStores[rnd(length(visitedDrinkStores)-1)].location;
				headedTo<-"DrinksStore";
			}
			
		}
	}
	
	action printLocation {
		write "The target of guest :" + targetPoint;
	}
	
	reflex changeStatus when: (isHungry=false and isThirsty=false){
		if flip(0.2){
			isHungry<-true;
		}
		else if flip(0.2){
			isThirsty<-true;
		}
		else if flip(0.01){
			isHungry<-true;
			isThirsty<-true;
		}
		else{
			isHungry<-false;
			isThirsty<-false;
		}
		
		if flip(0.05){
			isBad<-true;
		}
	}
	
	reflex moveToTarget when: targetPoint !=nil
	{
		do goto target:targetPoint;
	}
	
	reflex enterStore when: (targetPoint != nil) and (location distance_to(targetPoint) < 3)
	{	
		if(isBad=true and headedTo="InfoCenter"){
			ask InformationCenter{
				if not ( self.badGuests contains myself){
					self.badGuests<-self.badGuests+myself;
					myself.targetPoint<-self.location+1;
				}
				
			}
		}else{
			
			totalDistance <- totalDistance + distance_to(lastLocation, location);
			lastLocation <- location;
			if(headedTo="InfoCenter"){
				ask InformationCenter  {
					FestivalStore nearest <- FestivalStore(self.which_store(myself.isHungry, myself.isThirsty,myself.visitedFoodStores,myself.visitedDrinkStores));
					myself.targetPoint <-nearest.location;
					if (nearest.hasFood=true and nearest.hasDrinks=false){
						myself.headedTo<-"FoodStore";
						myself.visitedFoodStores<-myself.visitedFoodStores + nearest;
					}else if (nearest.hasFood=false and nearest.hasDrinks=true) {
						myself.headedTo<-"DrinksStore";
						myself.visitedDrinkStores<-myself.visitedDrinkStores + nearest;
					}else if (nearest.hasFood=true and nearest.hasDrinks=true){
						myself.headedTo<-"FoodStore";
						myself.visitedFoodStores<-myself.visitedFoodStores + nearest;
					}else{
						write "Unknown Target";
						myself.targetPoint<-nil;
						myself.isHungry<-false;
						myself.isThirsty<-false;
					}
				}
			}	
			else if ( headedTo ="FoodStore" ){
				self.isHungry<-false;
				self.targetPoint<-nil;
				self.headedTo<-nil;
			}
			else if ( headedTo ="DrinksStore" ){
				self.isThirsty<-false;
				self.targetPoint<-nil;
				self.headedTo<-nil;
			}
			else {
				headedTo<-nil;
				targetPoint<-nil;
				isHungry<-false;
				isThirsty<-false;
			}
		}
	}
	
	reflex evaluate_proposal when: !(empty(cfps)) {
		loop guestMessage over: cfps{
			write "message " + guestMessage.contents;
			int auctionId;
			float itemPrice;
			int round;
			point auctionLocation;
			if guestMessage.contents[0]!=nil{
				auctionId <- int(guestMessage.contents[0]);
				
			}else{
				auctionId <-nil;
			}
			string actionType <- guestMessage.contents[1];
			string itemType <- guestMessage.contents[2];
			if guestMessage.contents[3]!=nil{
				itemPrice <- float(guestMessage.contents[3]);
			}
			else{
				itemPrice <- nil;				
			}
			if guestMessage.contents[4]!=nil{
				round <- int(guestMessage.contents[4]);
			}else{
				round <- nil;
			}
			auctionLocation<-point(guestMessage.contents[5]);
			
			if actionType = "start" and flip(1.0){
				do accept_proposal message: guestMessage contents: [auctionId,"yes",round] ;
				
			 }
			 else if actionType = "start"{
			 	do reject_proposal message: guestMessage contents: [auctionId,"no",round] ;
			 	
			 }else if actionType = "ask"{
			 	if wallet>=itemPrice and flip(0.5){
			 		do accept_proposal message: guestMessage contents: [auctionId,"yes",round] ;
			 		
			 	}else{
			 		do reject_proposal message: guestMessage contents: [auctionId,"no",round] ;
			 		
			 	}
			 }
			 
				 
		}
//		do accept_proposal message: proposalFromInitiator contents: ['OK! It \'s hot today!'] ;
	}
	
	
	
	// Visual Aspect
	aspect base {
		rgb agentColor <- rgb("green");
		
		if (isHungry and isThirsty) {
			agentColor <- rgb("blue");
		} else if (isThirsty) {
			agentColor <- rgb("darkorange");
		} else if (isHungry) {
			agentColor <- rgb("purple");
		}
		
		if (isBad=true){
			agentColor <- rgb("red");
		}
		draw circle(1) color: agentColor;
	}
}


species FestivalStore
{
	bool hasFood;
	bool hasDrinks;
	point targetPoint <- nil;
	
	aspect base {
		rgb storeColor <- rgb("blue");
		
		if (hasFood=true and hasDrinks=false) {
			storeColor <- rgb("purple");
		} else {
			storeColor <- rgb("darkorange");
		}
		
		draw square(2) color: storeColor;
	}
}

species InformationCenter
{
	list<FestivalGuest> badGuests;
	init {
		location <-{10,10,10};
		shape <-circle(1);
		badGuests<-[];
		targetPoint<-location;
	}
	point targetPoint;
	string name;
	
	action printLocation {
		write "The location of info center :" + location;
	}
	
	FestivalStore which_store(bool isHungry, bool isThirsty,list<FestivalStore> VisitedFoodStores,list<FestivalStore> VisitedDrinkStores){
		FestivalStore store;
		if(isHungry=true and (length(VisitedFoodStores)=0)){
			store<-get_nearest_store(isHungry,isThirsty);
		}else if (isHungry=true){
			store<-get_random_store(isHungry,isThirsty);
		}else if(isThirsty=true and (length(VisitedDrinkStores)=0)){
			store<-get_nearest_store(isHungry,isThirsty);
		}else if (isThirsty=true){
			store<-get_random_store(isHungry,isThirsty);
		}
		
		return store;
	}
	
	
	FestivalStore get_nearest_store(bool isHungry, bool isThirsty){
		float minDist <- #max_float;
		FestivalStore nearestStore;
		loop counter from: 1 to: numberOfFoodStores + numberOfDrinkStores{
	        FestivalStore store <- FestivalStore[counter - 1];
	        point storeLocation <- store.location;
	        point infCenterLocation <-targetPoint;
	        float distance <- distance_to(storeLocation, infCenterLocation);
	        if (distance < minDist) {
	        	
	        	if (isHungry=true and store.hasFood=true){
		        	minDist<-distance;
		        	nearestStore<-store;
		        	}
		        else if (isThirsty=true and store.hasDrinks=true){
		        	minDist<-distance;
		        	nearestStore<-store;
		        }
		        else{}
	        }
		}
		return nearestStore;
	}
	
	FestivalStore get_random_store(bool isHungry, bool isThirsty){
		FestivalStore store;
		if(isHungry=true){
			store<-FoodStores[rnd(length(FoodStores)-1)];
			
		}else if(isThirsty=true){
			store<-DrinkStores[rnd(length(DrinkStores)-1)];
			
		}
		return store;
	}
	
	reflex notifySecurityGuard when: (length(badGuests)>0){
		ask SecurityGuard{
			self.targetPoint<-myself.location;
			headTo<-"InfoCenter";
			
		}
	}
	
	

	aspect base {
		rgb infoCenterColor <- rgb("magenta");
		draw hexagon(3) color: infoCenterColor;
	}
}


species SecurityGuard skills:[moving]
{
	point targetPoint <- nil;
	string headTo<- nil;
	reflex beIdle when: targetPoint = nil
	{
		do wander;
	}
	
	reflex moveToTarget when: targetPoint !=nil
	{
		do goto target:targetPoint;
	}
	
	reflex enterStore when: (targetPoint != nil) and (location distance_to(targetPoint) < 1)
	{
		ask InformationCenter{
			loop counter from: 1 to: length(self.badGuests){
				ask badGuests[counter-1]{
					do die;
				}
								
			}
			badGuests<-[];
			myself.targetPoint<-nil;
		}
	}
	

	
	aspect base {
		rgb guardColor <- rgb("black");
		
		draw circle(1) color: guardColor;
	}
}

species AuctionHouse skills:[fipa]{
	string  auctionType;
	string itemKind;
	int maxPrice;
	int minPrice;
	int currentPrice;
	int round;
	int priceStep;
	list participatingGuests;
	bool auctionInProgress;
	bool participationClosed;
	int id;
	list<string> candidateTypes;
	list<message> acceptedProposals;
	int numRejected;
	float startTime;
	bool changedRound;
	
	init{
		participatingGuests <- [];
		auctionInProgress<-false;
		candidateTypes<-["clothes", "patches", "posters"];
		numRejected<-0;
		changedRound<-true;
		round<-0;
	}
	
	
	reflex start_auction when: (time = 1) and auctionInProgress=false {
		auctionInProgress<-true;
		startTime<-time;
		minPrice <- rnd(50);
		maxPrice <- rnd(51, 500);
		priceStep <- rnd(1, 5);
		currentPrice<-maxPrice;
		itemKind <- candidateTypes[rnd(length(candidateTypes)-1)];
		do start_conversation to: list(FestivalGuest) protocol: 'fipa-propose' performative: 'cfp' contents: [id, 'start', itemKind, maxPrice,round,location] ;
		round<-	round+1;
	}
	
	reflex read_accept_proposals when: (length(accept_proposals) !=0) and participationClosed!=true{
		loop acceptMessage over: accept_proposals{
			participatingGuests <- participatingGuests + acceptMessage.sender;
		}
	}
	
	reflex close_participation when: time= startTime+10 {
		participationClosed<-true;
	}
	

	reflex send_ask when:participationClosed=true and changedRound=true and participatingGuests!=[]{
		write "send ask "+round+ " id "+id;
		do start_conversation to: list(participatingGuests) protocol: 'fipa-propose' performative: 'cfp' contents: [id, 'ask', itemKind, currentPrice, round,location] ;
		changedRound<-false;
		
	}
	
	reflex gather_responses when: ((participationClosed=true and changedRound=false and participatingGuests!=[]) and (accept_proposals!=[] or reject_proposals!=[])){
		loop accepted over:accept_proposals{
			if (accepted.contents[0]=id and int(accepted.contents[2])=round){
				acceptedProposals<-acceptedProposals+accepted;
			}
		}
		loop rejected over:reject_proposals{
			if (rejected.contents[0]=id and int(rejected.contents[2])=round){
				numRejected<-numRejected+1;
			}
		}
	}
	//add time OUT 
	reflex change_round when: ((length(acceptedProposals)+numRejected)= length(participatingGuests)){
		if length(acceptedProposals)>0{	
			do start_conversation to: list(participatingGuests) protocol: 'fipa-propose' performative: 'cfp' contents: [id, 'stop',nil,nil,nil,location] ;
			write "item sold to " +acceptedProposals[0].sender;
			auctionType<-nil;
			itemKind<-nil;
			maxPrice<-nil;
			minPrice<-nil;
			currentPrice<-nil;
			round<-nil;
			participatingGuests<-[];
			auctionInProgress<-false;
			participationClosed<-false;
			acceptedProposals<-[];
			numRejected<-0;
			startTime<-nil;

		}
		else{
			currentPrice<-currentPrice-priceStep;
			acceptedProposals<-[];
			numRejected<-0;
			write "item not sold in round " +round+ " and id " +id;
			round<-round+1;
		}
		changedRound<-true;
	}
	
	
	aspect base {
		rgb auctionInitiatorColor <- rgb("yellow");
		
		draw square(3) color: auctionInitiatorColor;
	}
	
	
}

experiment myExperiment type:gui {
	output {
		display myDisplay {
			// Display the species with the created aspects
			species FestivalGuest aspect:base;
			species FestivalStore aspect:base;
			species InformationCenter aspect:base;
			species SecurityGuard aspect:base;
			species AuctionHouse aspect:base;
			
		}
	}
}

/// add time out
//add interests of customer
//+AUCTION TYPE
//