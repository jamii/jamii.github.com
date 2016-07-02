---
layout: post
title: "Smarkets API documentation"
date: 2010-07-30 06:16
comments: true
categories: project
redirect_from: one/1280/511009/453845
---

I want to write a little about the documentation system I wrote for the smarkets API. The main concern I had with the documentation was that it would be incorrect or become out of sync with the code, especially since I didn't really understand the system when I started documenting it. To prevent this I built a couple of documentation tools that have paid for themselves many times over.

<!--more-->

We have our own home-grown and slightly crappy web framework which powers the public API. A typical resource declaration looks like this:

``` erlang
   #a{m=[fun rest_aux:user_id/1, emails,
         fun rest_aux:email/1, fun rest_aux:hash/1],
      f=[{'PUT', fun rest_users:user_or_admin/3}],
      scope=[{'PUT', private}],
      pu=fun(UserId, Email, Hash, _Auth, Ctx) ->
             case users:verify_email(UserId, Email, Hash) of
               ok ->
                 smarkets_rest:nc(Ctx);
               {error, conflict} ->
                 smarkets_rest:cfl(Ctx);
               {error, not_found} ->
                 smarkets_rest:nf(Ctx)
             end
         end}
```

To this I added a documentation field for each method:

``` erlang
   #a{m=[fun rest_aux:user_id/1, emails,
         fun rest_aux:email/1, fun rest_aux:hash/1],
      f=[{'PUT', fun rest_users:user_or_admin/3}],
      scope=[{'PUT', private}],
      pu_doc = #'doc.method'{
        doc = "Verify the specified email using the hash code sent to the user",
        responses =
          [{200, "Successful"}
          ,{404, "Specified user or email does not exist"}
          ,{409, "Incorrect hash code"}]},
      pu=fun(UserId, Email, Hash, _Auth, Ctx) ->
             case users:verify_email(UserId, Email, Hash) of
               ok ->
                 smarkets_rest:nc(Ctx);
               {error, conflict} ->
                 smarkets_rest:cfl(Ctx);
               {error, not_found} ->
                 smarkets_rest:nf(Ctx)
             end
         end}
```

From this the documentation system generates a json object which is stored in couchdb:

``` json
{
   "_id": "users/{user_id}/emails/{email}/{hash}",
   "_rev": "1-0c4c3aad1227a62429ffb0c05a7059f1",
   "type": "doc.action",
   "term": {
       "methods": {
           "PUT": {
               "type": "doc.method",
               "term": {
                   "headers": {
                   },
                   "opt_params": {
                   },
                   "req_params": {
                   },
                   "scope": "private",
                   "role": "rest_users.user_or_admin",
                   "auth": "needs_user",
                   "responses": {
                       "200": "Successful",
                       "404": "Specified user or email does not exist",
                       "409": "Incorrect hash code"
                   },
                   "doc": "Verify the specified email using the hash code sent to the user"
               }
           }
       },
       "path": "users/{user_id}/emails/{email}/{hash}"
   }
}
```

This json object is used by a couple of different scripts. Both the [public api reference](http://smarkets.com/api/documentation/) and our own internal api reference are produced from these json objects. I also added a fuzzer which can read the json documentation and generate calls with both random data and records pulled from the development database. The fuzzer logs the results of these calls like this:

``` json
{
   "_id": "320f2a4bc956334c66c84a4d9f6160a0",
   "_rev": "1-a109f7aa2906e2452e45a49d649674cb",
   "body": "{}",
   "code": 403,
   "path_spec": "users/{user_id}/emails/{email}/{hash}",
   "method": "PUT",
   "headers": {
       "Content-type": "application/json",
       "Authorization": "UserLogin token=\"O3bHthtJ6wumlt0yjf0q8OrYURMBKiRbfNRmhfGLJNCXhcXkSrzyPVzm47MoWD_lt6UdOJlA8wf1AWY~\""
   },
   "path": "users/54ad2cc2a1dd2871518c528a11a40f00/emails/jMt%40XPqKYLNx/50584d82c756b2e4a53c8695553ae34a",
   "response": null,
   "port": 9000
}
```

Another set of scripts then combs through these tables looking for errors. Anything that returns '500 internal server error' is flagged. Calls which return '400 bad request' and are not tagged as being deliberately malformed are also flagged. Same goes for any response code which isn't documented for that call and any documented response code which isn't observed in the fuzzer table. One particularly useful script lists methods which are accessible via the public port.

This system has worked out quite well so far. The documentation is embedded directly next to the related code so its hard to forget to update it when changing the code. The fuzzer is worth its weight in gold and has uncovered countless bugs and weird corner cases. For such a crude fuzzer it generates suprisingly good code coverage. The next step is to combine the fuzzer with a smallcheck-style test system in order to better narrow down errors in long sequences of calls.
