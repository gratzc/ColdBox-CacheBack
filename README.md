ColdBox-CacheBack
=================

A cool annotation based Caching Aspect for WireBox/ColdBox that provides caching without blocking requests during refresh

This interceptor will inspect objects for the 'cacheBack' annotation and if found,
it will wrap it in a thread creating cache.
This allows the function to be cached without waiting for it to refresh.
Inspiration from God and from this library.
	http://django-cacheback.readthedocs.org/en/latest/

	This aspect is a self binding
	aspect for WireBox that registers itself using the annotations below
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
	Then all you need to do is add the annotation cachback to your methods
	myFunction() cacheback refreshRate=120 timeout=240 {}
  
Keep in mind like all things caching, testing and tuning is very important.  This can be used in very specfic scenarios
when you want to keep cache refreshing, but don't want users to wait for the refresh.
