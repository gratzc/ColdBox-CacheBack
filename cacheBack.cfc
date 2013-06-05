/**
@Author Curt Gratz/Scott Coldwell

@Description A cool annotation based Caching Aspect for WireBox
	This interceptor will inspect objects for the 'cacheBack' annotation and if found,
	it will wrap it in a thread creating cache.
	This allows the function to be cached without waiting for it to refresh.
	Inspiration from God and from this library.
		http://django-cacheback.readthedocs.org/en/latest/#

	This aspect is a self binding
	aspect for WireBox that registers itself using the two annotations below
	You can control the refresh rate for your cache and the timeout in a number of ways
		1) You can add an annotation to your method called refreshRate and timeout
			ie function myFunction() cacheback refreshRate=120 timeout=240 {}
			This will set cache to refresh every 2 mins and timeout every 4 mins.
		2) You can add a settings to your coldbox config called cacheBack.  The setting will be a structure with
		   keys of refreshRate and timeout
			cacheBack = {refreshRate=60,timeout=120}
			This will set cache to refresh every 60 mins and timeout every 120 mins.
		3) You can use our default timeouts which are a refresh rate 18 mins and a timeout of 20 mins
	All refresh rates and timeouts are in seconds

	To activate this aspect you will need to map it in your WireBox binder.  This can be done like below
	mapAspect("cacheBack").to("model.aspects.cacheBack");

@classMatcher any
@methodMatcher annotatedWith:cacheBack

Advice for caching an function without blocking
**/
component output="false" implements="coldbox.system.aop.MethodInterceptor" hint="Advice for caching an event without blocking" {

	/**
	* Init
	* @coldboxConfig.inject coldbox:configBean
	* @coldboxUtil.inject id:coldbox.system.core.util.Util
	*/
	public any function init(settings={refreshRate = 1080,timeout = 1200}, coldboxConfig, coldboxUtil) {
		variables.settings = arguments.settings;

		//if we have coldbox settings, use those for our default
		var coldBoxSetting = arguments.coldboxConfig.getKey("cacheBack",{});
		if(structKeyExists(coldBoxSetting, "refreshRate")) {
			variables.settings.refreshRate = coldBoxSetting.refreshRate;
		}
		if(structKeyExists(coldBoxSetting, "timeout")) {
			variables.settings.timeout = coldBoxSetting.timeout;
		}

		variables.coldboxUtil = arguments.coldboxUtil;

		return this;
	}

	/*
	* invokeMethod
	*/
	public any function invokeMethod(required invocation) output="false" {
		var methodArguments = arguments.invocation.getArgs();
		var methodName = arguments.invocation.getMethod();

		//create a hash of the arguments
		var methodArgumentsWithoutFwcache = structCopy(methodArguments);
		structDelete(methodArgumentsWithOutFwcache, "fwcache");
		var hash = hash(SerializeJSON(methodArgumentsWithOutFwcache));

		//create unique cache and lock names based on arguments passed
		var cacheName = methodName & hash & "_cache";
		var lockName = methodName & hash & "_lock";

		//default to whats in the settings
		var refreshRate = settings.refreshRate;
		var timeout = settings.timeout;

		//if we have metadata for our cache, use that, otherwise we use the settings
		var md = arguments.invocation.getMethodMetadata();
		if(structKeyExists(md, "refreshRate")) {
			refreshRate = md.refreshRate;
		}
		if(structKeyExists(md, "timeout")) {
			timeout = md.timeout;
		}

		//default the arguments
		if(!structKeyExists(methodArguments, "fwcache")){ methodArguments.fwcache=false; }

		//check to see if we are forcing a cache refresh
		var forceRefresh = (structKeyExists(url,'fwcache') && url.fwcache == 1) || methodArguments.fwcache;

		//check if we manually reset the lock
		if(structKeyExists(url,'resetLock') && url.resetLock == 1) {application[lockName] = false;}

		//get the item from cache
		var cacheResult = cacheGet(cacheName);

		if (isNull(cacheResult) || forceRefresh) {
			// allow call to continue and get teh results
			var results = arguments.invocation.proceed();
			//add our softTimeout to what we are caching
			var cacheResult = {
				results=results,
				softTimeout = dateAdd("s", refreshRate, now())
			};
			//put the item in cache until it timeouts
			cachePut(cacheName,cacheResult,createtimespan(0,0,0,timeout));
		//if we are in the refresh timeframe, launch a thread and refresh
		} else if (cacheResult.softTimeout < now()) {
			//prevent more then one thread from firing
			var spawnAThread = false;

			lock name="#lockName#" timeout="1" throwOnTimeout="no" {
				if(!structKeyExists(application, lockName) || !application[lockName]) {

					//lock so we don't dogpile the refresh.
					spawnAThread = true;
					application[lockName] = true;
				}
			}
			if (spawnAThread) {
				try{
					//if we aren't already in a thread, then launch one, otherwise update with no thread
					if(!coldboxUtil.inThread()) {
						thread action="run" name="#cacheName#" cacheName=cacheName lockName=lockName methodName=methodName invocation=arguments.invocation methodArguments=methodArguments softTimeout=CacheResult.softTimeout {

							var newCache = cacheGet(cacheName);

							//double check that the cache hasn't changed, if it has, no need to do anything because it already updated.
							if(newCache.softTimeout == softTimeout) {
								//the cache hasn't changed so update in with the thread
								var args = methodArguments;
								args.fwcache = true;
								invocation.setArgs(args);
								invokeMethod(invocation);
							}

							//let the application know we are done
							application[lockName] = false;

						}
					} else {
						//lock so we don't dogpile the refresh.
						lock name="#lockName#" timeout="1" throwOnTimeout="no" {
							//let the application know we are running
							application[lockName] = true;
							//the cache hasn't changed so update in with the thread
							var args = methodArguments;
							args.fwcache = true;
							invocation.setArgs(args);
							invokeMethod(invocation);
							//let the application know we are done
							application[lockName] = false;
						}
					}
				} catch (any e) {
					//the thread failed, so this person has to pay to refresh the cache
					//lock so we don't dogpile the refresh.
					lock name="#lockName#" timeout="1" throwOnTimeout="no" {
						//let the application know we are running
						application[lockName] = true;
						//the cache hasn't changed so update in with the thread
						var args = methodArguments;
						args.fwcache = true;
						invocation.setArgs(args);
						invokeMethod(invocation);
						//let the application know we are done
						application[lockName] = false;
					}
				}
			}
		}

		//return the results
		return cacheResult.results;
	}


}